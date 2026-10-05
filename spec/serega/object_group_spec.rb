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

    it "adds the objects and returns the range of their results" do
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

      it "returns the index of its result" do
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

      it "returns a range of one result" do
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
    subject(:results) do
      object_group.build
      object_group.results
    end

    before { object_group.add([user1, user2], true) }

    it "builds the result of every object" do
      expect(results).to eq [{name: "Ann"}, {name: "Bob"}]
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
        expect(results).to eq [{name: "Ann", posts: [{title: "Hello"}]}, {name: "Bob", posts: nil}]
      end
    end

    context "with a batch attribute" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, batch: {use: proc { |users| users.to_h { |user| [user, user.name.upcase] } }, id: :itself} } }

      it "reads the values from the loaded batch" do
        expect(results).to eq [{name: "ANN"}, {name: "BOB"}]
      end
    end
  end

  describe "#load_batch" do
    let(:loader) { double(load: loaded_values) }
    let(:loaded_values) { {1 => "Ann"} }

    before { object_group.add([user1, user2], true) }

    it "loads values of all objects with the context" do
      expect(object_group.load_batch(loader)).to eq loaded_values
      expect(loader).to have_received(:load).with([user1, user2], context)
    end

    it "loads the same loader once" do
      object_group.load_batch(loader)
      object_group.load_batch(loader)

      expect(loader).to have_received(:load).once
    end

    it "loads different loaders separately" do
      other_loader = double(load: {})

      object_group.load_batch(loader)
      object_group.load_batch(other_loader)

      expect(loader).to have_received(:load).once
      expect(other_loader).to have_received(:load).once
    end
  end
end
