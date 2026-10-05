# frozen_string_literal: true

RSpec.describe Serega::SeregaObjectGroup do
  subject(:object_group) { user_serializer::SeregaObjectGroup.new(run, plan, [user1, user2], references) }

  let(:user_serializer) { Class.new(Serega) { attribute :name } }
  let(:plan) { user_serializer::SeregaPlan.new(nil, {}) }
  let(:run) { Serega::SeregaEngine::Run.new(mode: :hash, context: context) }
  let(:context) { {locale: :en} }
  let(:references) { [2] }
  let(:user1) { double(name: "Ann") }
  let(:user2) { double(name: "Bob") }

  describe ".serializer_class" do
    it "returns the serializer class" do
      expect(user_serializer::SeregaObjectGroup.serializer_class).to equal user_serializer
    end
  end

  describe "#objects" do
    it "returns the serialized objects" do
      expect(object_group.objects).to eq [user1, user2]
    end

    context "when the serializer has a presenter" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :name

          presenter { def name = "Mr. #{super}" }
        end
      end

      it "returns the objects wrapped in presenters" do
        expect(object_group.objects.map(&:name)).to eq ["Mr. Ann", "Mr. Bob"]
      end
    end
  end

  describe "#discover" do
    subject(:discover) { object_group.discover }

    let(:post_serializer) { Class.new(Serega) { attribute :title } }

    let(:user_serializer) do
      child = post_serializer
      Class.new(Serega) do
        attribute :name
        attribute :posts, serializer: child
      end
    end

    let(:post) { double(title: "Hello") }
    let(:user1) { double(name: "Ann", posts: [post]) }
    let(:user2) { double(name: "Bob", posts: nil) }

    before { allow(run).to receive(:add_object_group).and_call_original }

    it "adds a group of the related objects" do
      discover

      expect(run).to have_received(:add_object_group).with(plan.relation_points[0].child_plan, [post], [1, nil])
    end

    context "when reading a relation raises an error" do
      let(:user_serializer) do
        Class.new(Serega) { attribute :posts, serializer: Class.new(Serega), value: proc { raise "boom" } }
      end

      it "adds the attribute name and the serializer to the error message" do
        expect { discover }
          .to raise_error RuntimeError, "boom\n(when serializing 'posts' attribute in #{user_serializer})"
        expect(run).not_to have_received(:add_object_group)
      end
    end

    context "with preloads" do
      let(:preload_handler) { double(call: nil) }

      let(:user_serializer) do
        handler = preload_handler
        Class.new(Serega) do
          attribute :name, preload: :profile
          preload_with handler
        end
      end

      it "runs the preloads of the objects" do
        discover

        expect(preload_handler).to have_received(:call).with([user1, user2], :profile)
      end
    end

    context "with preloads and a presenter" do
      let(:preload_handler) { double(call: nil) }

      let(:user_serializer) do
        handler = preload_handler
        Class.new(Serega) do
          attribute :name, preload: :profile
          preload_with handler
          presenter {}
        end
      end

      it "runs the preloads of the objects without presenters" do
        discover

        expect(preload_handler).to have_received(:call).with([user1, user2], :profile)
      end
    end

    context "with preloads and no preload handler" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, preload: :profile } }

      it "raises an error" do
        expect { discover }
          .to raise_error Serega::SeregaError, start_with("The :preload option requires a preload handler")
      end
    end

    context "when a preload raises an error" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :name, preload: :profile
          preload_with proc { raise "boom" }
        end
      end

      it "adds the attribute name and the serializer to the error message" do
        expect { discover }
          .to raise_error RuntimeError, "boom\n(when serializing 'name' attribute in #{user_serializer})"
      end
    end
  end

  describe "#build" do
    subject(:serialized) do
      object_group.build
      object_group.serialized
    end

    it "builds the serialized object of every object" do
      expect(serialized).to eq [{name: "Ann"}, {name: "Bob"}]
    end

    context "with a relation" do
      let(:post_serializer) { Class.new(Serega) { attribute :title } }

      let(:user_serializer) do
        child = post_serializer
        Class.new(Serega) do
          attribute :name
          attribute :posts, serializer: child
        end
      end

      let(:post1) { double(title: "Hello") }
      let(:post2) { double(title: "World") }
      let(:user1) { double(name: "Ann", posts: [post1, post2]) }
      let(:user2) { double(name: "Bob", posts: nil) }
      let(:child_groups) { [] }

      before do
        allow(run).to receive(:add_object_group).and_wrap_original do |method, *arguments|
          child_group = method.call(*arguments)
          child_groups << child_group
          child_group
        end

        object_group.discover
        child_groups.each(&:build)
      end

      it "takes the relation values from the built group of related objects" do
        expect(serialized).to eq [{name: "Ann", posts: [{title: "Hello"}, {title: "World"}]}, {name: "Bob", posts: nil}]
        expect(run).to have_received(:add_object_group).once
      end
    end

    context "with a batch attribute" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :name, batch: {use: proc { |users| users.to_h { |user| [user, user.name.upcase] } }, id: :itself}
        end
      end

      it "reads the values from the loaded batch" do
        expect(serialized).to eq [{name: "ANN"}, {name: "BOB"}]
      end
    end

    context "with two attributes of one batch loader" do
      let(:loads) { [] }

      let(:user_serializer) do
        loads = self.loads
        named = {user1 => "ANN", user2 => "BOB"}
        Class.new(Serega) do
          batch(:names) do |users, context|
            loads << [users, context]
            named
          end

          attribute :name, batch: {use: :names, id: :itself}
          attribute :nickname, batch: {use: :names, id: :itself}
        end
      end

      it "loads the batch once with the objects and the context" do
        expect(serialized).to eq [{name: "ANN", nickname: "ANN"}, {name: "BOB", nickname: "BOB"}]
        expect(loads).to eq [[[user1, user2], context]]
      end
    end

    context "when a batch loader raises an error" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, batch: {use: proc { |_users| raise "boom" }, id: :itself} } }

      it "adds the attribute name and the serializer to the error message" do
        expect { serialized }
          .to raise_error RuntimeError, "boom\n(when serializing 'name' attribute in #{user_serializer})"
      end
    end
  end

  describe "#relation_values" do
    subject(:relation_values) do
      object_group.build
      object_group.relation_values
    end

    let(:user3) { double(name: "Cat") }
    let(:object_group) { user_serializer::SeregaObjectGroup.new(run, plan, [user1, user2, user3], references) }
    let(:references) { [2, nil, Serega::SeregaEngine::SINGLE_OBJECT] }

    it "takes the serialized objects in the order of the references" do
      expect(relation_values).to eq [[{name: "Ann"}, {name: "Bob"}], nil, {name: "Cat"}]
    end
  end
end
