# frozen_string_literal: true

RSpec.describe Serega::SeregaObjectGroup do
  subject(:object_group) { run.object_group(plan) }

  let(:user_serializer) { Class.new(Serega) { attribute :name } }
  let(:plan) { user_serializer::SeregaPlan.new(nil, {}) }
  let(:run) { Serega::SeregaEngine::Run.new(mode: :hash, context: context) }
  let(:context) { {locale: :en} }
  let(:user1) { double(name: "Ann") }
  let(:user2) { double(name: "Bob") }

  describe ".serializer_class" do
    it "returns the serializer class" do
      expect(user_serializer::SeregaObjectGroup.serializer_class).to equal user_serializer
    end
  end

  describe "#add" do
    subject(:reference) { object_group.add(object, many) }

    let(:object) { [user1, user2] }
    let(:many) { nil }

    it "adds the objects and returns the range of their serialized objects" do
      expect(reference).to eq 0...2
      expect(object_group.objects).to eq [user1, user2]
    end

    context "when the group has objects" do
      before { object_group.add(user1, false) }

      it "returns the range after the earlier objects" do
        expect(reference).to eq 1...3
        expect(object_group.objects).to eq [user1, user1, user2]
      end
    end

    context "with one object" do
      let(:object) { user1 }

      it "returns the index of its serialized object" do
        expect(reference).to eq 0
        expect(object_group.objects).to eq [user1]
      end
    end

    context "with nil" do
      let(:object) { nil }

      it "adds no objects" do
        expect(reference).to be_nil
        expect(object_group.objects).to eq []
      end
    end

    context "when many is true and the object is not a collection" do
      let(:object) { user1 }
      let(:many) { true }

      it "returns a range of one serialized object" do
        expect(reference).to eq 0...1
      end
    end

    context "when many is false and the object is a collection" do
      let(:many) { false }

      it "adds the collection as one object" do
        expect(reference).to eq 0
        expect(object_group.objects).to eq [[user1, user2]]
      end
    end

    context "when the serializer has a presenter" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :name

          presenter { def name = "Mr. #{super}" }
        end
      end

      it "adds the objects wrapped in presenters" do
        reference

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

    before { object_group.add([user1, user2], true) }

    it "adds the related objects to the group of the relation plan" do
      discover

      expect(run.object_group(plan.relation_points[0].child_plan).objects).to eq [post]
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

    context "when reading a relation raises an error" do
      let(:user_serializer) do
        Class.new(Serega) { attribute :posts, serializer: Class.new(Serega), value: proc { raise "boom" } }
      end

      it "adds the attribute name and the serializer to the error message" do
        expect { discover }
          .to raise_error RuntimeError, "boom\n(when serializing 'posts' attribute in #{user_serializer})"
      end
    end
  end

  describe "#build" do
    subject(:serialized) do
      object_group.build
      object_group.serialized
    end

    before { object_group.add([user1, user2], true) }

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

      let(:post) { double(title: "Hello") }
      let(:user1) { double(name: "Ann", posts: [post]) }
      let(:user2) { double(name: "Bob", posts: nil) }

      before do
        object_group.discover
        run.object_group(plan.relation_points[0].child_plan).build
      end

      it "takes the relation values from the built group of the relation plan" do
        expect(serialized).to eq [{name: "Ann", posts: [{title: "Hello"}]}, {name: "Bob", posts: nil}]
      end
    end

    context "with a batch attribute" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, batch: {use: proc { |users| users.to_h { |user| [user, user.name.upcase] } }, id: :itself} } }

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

  describe "#serialized_for" do
    subject(:serialized) { object_group.serialized_for(reference) }

    let(:reference) { 1 }

    before do
      object_group.add([user1, user2], true)
      object_group.build
    end

    it "returns the serialized object of an index" do
      expect(serialized).to eq(name: "Bob")
    end

    context "with a range" do
      let(:reference) { 0...2 }

      it "returns the serialized objects of the range" do
        expect(serialized).to eq [{name: "Ann"}, {name: "Bob"}]
      end
    end

    context "with nil" do
      let(:reference) { nil }

      it "returns nil" do
        expect(serialized).to be_nil
      end
    end
  end
end
