# frozen_string_literal: true

RSpec.describe Serega::SeregaSourceGroup do
  subject(:source_group) { user_serializer::SeregaSourceGroup.new(run, plan, [user1, user2], pulls) }

  let(:user_serializer) { Class.new(Serega) { attribute :name }.freeze }
  let(:plan) { user_serializer::SeregaPlan.new(nil, {}) }
  let(:run) { Serega::SeregaEngine::Run.new(mode: :hash, context: context) }
  let(:context) { {locale: :en} }
  let(:pulls) { [2] }
  let(:user1) { double(name: "Ann") }
  let(:user2) { double(name: "Bob") }

  describe ".serializer_class" do
    it "returns the serializer class" do
      expect(user_serializer::SeregaSourceGroup.serializer_class).to equal user_serializer
    end
  end

  describe "#sources" do
    it "returns the sources" do
      expect(source_group.sources).to eq [user1, user2]
    end

    context "when the serializer has a presenter" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :name

          presenter { def name = "Mr. #{super}" }
          freeze
        end
      end

      it "returns the sources wrapped in presenters" do
        expect(source_group.sources.map(&:name)).to eq ["Mr. Ann", "Mr. Bob"]
      end
    end
  end

  describe "#discover" do
    subject(:discover) { source_group.discover }

    let(:post_serializer) { Class.new(Serega) { attribute :title }.freeze }

    let(:user_serializer) do
      child = post_serializer
      Class.new(Serega) do
        attribute :name
        attribute :posts, serializer: child
        freeze
      end
    end

    let(:post) { double(title: "Hello") }
    let(:user1) { double(name: "Ann", posts: [post]) }
    let(:user2) { double(name: "Bob", posts: nil) }

    it "returns a child group of the relation sources" do
      expect(discover.size).to eq 1

      child_group = discover[0]
      expect(child_group.plan).to equal plan.relation_points[0].child_plan
      expect(child_group.sources).to eq [post]
      expect(child_group.pulls).to eq [1, nil]
    end

    context "without relations" do
      let(:user_serializer) { Class.new(Serega) { attribute :name }.freeze }

      it "returns no child groups" do
        expect(discover).to eq []
      end
    end

    context "when reading a relation raises an error" do
      let(:user_serializer) do
        Class.new(Serega) { attribute :posts, serializer: Class.new(Serega).freeze, value: proc { raise "boom" } }.freeze
      end

      it "adds the attribute name and the serializer to the error message" do
        expect { discover }
          .to raise_error RuntimeError, "boom\n(when serializing the 'posts' attribute in #{user_serializer}, #{user_serializer.attributes[:posts].location})"
      end
    end

    context "when the method of a relation raises an error" do
      let(:user1) { Struct.new(:name).new("Ann") }

      it "starts the backtrace at the line of the attribute" do
        location = user_serializer.attributes[:posts].location

        expect { discover }.to raise_error(NoMethodError) { |error| expect(error.backtrace.first).to start_with("#{location}:") }
      end
    end

    context "with preloads" do
      let(:preload_handler) { double(call: nil) }

      let(:user_serializer) do
        handler = preload_handler
        Class.new(Serega) do
          attribute :name, preload: :profile
          preload_with handler
          freeze
        end
      end

      it "runs the preloads of the sources" do
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
          freeze
        end
      end

      it "runs the preloads of the sources without presenters" do
        discover

        expect(preload_handler).to have_received(:call).with([user1, user2], :profile)
      end
    end

    context "with preloads and no preload handler" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, preload: :profile }.freeze }

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
          freeze
        end
      end

      it "adds the attribute name and the serializer to the error message" do
        expect { discover }
          .to raise_error RuntimeError, "boom\n(when serializing the 'name' attribute in #{user_serializer}, #{user_serializer.attributes[:name].location})"
      end
    end
  end

  describe "#build" do
    subject(:serialized) do
      source_group.build
      source_group.serialized
    end

    it "builds the serialized object of every source" do
      expect(serialized).to eq [{name: "Ann"}, {name: "Bob"}]
    end

    context "with a relation" do
      let(:post_serializer) { Class.new(Serega) { attribute :title }.freeze }

      let(:user_serializer) do
        child = post_serializer
        Class.new(Serega) do
          attribute :name
          attribute :posts, serializer: child
          freeze
        end
      end

      let(:post1) { double(title: "Hello") }
      let(:post2) { double(title: "World") }
      let(:user1) { double(name: "Ann", posts: [post1, post2]) }
      let(:user2) { double(name: "Bob", posts: nil) }

      before do
        child_groups = source_group.discover
        child_groups.each(&:build)
      end

      it "takes the relation values from the built child group" do
        expect(serialized).to eq [{name: "Ann", posts: [{title: "Hello"}, {title: "World"}]}, {name: "Bob", posts: nil}]
      end
    end

    context "with a relation of one source" do
      let(:avatar_serializer) { Class.new(Serega) { attribute :url }.freeze }

      let(:user_serializer) do
        child = avatar_serializer
        Class.new(Serega) do
          attribute :name
          attribute :avatar, serializer: child
          freeze
        end
      end

      let(:avatar) { double(url: "ann.png") }
      let(:user1) { double(name: "Ann", avatar: avatar) }
      let(:user2) { double(name: "Bob", avatar: nil) }

      before do
        child_groups = source_group.discover
        child_groups.each(&:build)
      end

      it "takes one serialized object for each source" do
        expect(serialized).to eq [{name: "Ann", avatar: {url: "ann.png"}}, {name: "Bob", avatar: nil}]
      end
    end

    context "with a batch attribute" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :name, batch: {use: proc { |users| users.to_h { |user| [user, user.name.upcase] } }, id: :itself}
          freeze
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
          freeze
        end
      end

      it "loads the batch once with the sources and the context" do
        expect(serialized).to eq [{name: "ANN", nickname: "ANN"}, {name: "BOB", nickname: "BOB"}]
        expect(loads).to eq [[[user1, user2], context]]
      end
    end

    context "when a batch loader raises an error" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, batch: {use: proc { |_users| raise "boom" }, id: :itself} }.freeze }

      it "adds the attribute name and the serializer to the error message" do
        expect { serialized }
          .to raise_error RuntimeError, "boom\n(when serializing the 'name' attribute in #{user_serializer}, #{user_serializer.attributes[:name].location})"
      end
    end
  end
end
