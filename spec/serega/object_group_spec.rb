# frozen_string_literal: true

RSpec.describe Serega::SeregaObjectGroup do
  subject(:object_group) { user_serializer::SeregaObjectGroup.new(run, plan) }

  let(:user_serializer) { Class.new(Serega) { attribute :name } }
  let(:plan) { user_serializer::SeregaPlan.new(nil, {}) }
  let(:run) { Serega::SeregaEngine::Run.new(mode: mode, context: context) }
  let(:mode) { :hash }
  let(:context) { {locale: :en} }
  let(:user1) { double(name: "Ann") }
  let(:user2) { double(name: "Bob") }

  describe ".serializer_class" do
    it "returns the serializer class" do
      expect(user_serializer::SeregaObjectGroup.serializer_class).to equal user_serializer
    end
  end

  describe "#add" do
    subject(:containers) { object_group.add(object, many) }

    let(:object) { [user1, user2] }
    let(:many) { nil }

    it "adds the objects and returns an empty container per object" do
      expect(containers).to eq [{}, {}]
      expect(object_group.objects).to eq [user1, user2]
      expect(object_group.containers).to eq containers
    end

    it "keeps objects of earlier calls" do
      object_group.add(user1, false)

      expect(containers).to eq [{}, {}]
      expect(object_group.objects).to eq [user1, user1, user2]
    end

    context "with one object" do
      let(:object) { user1 }

      it "returns one container" do
        expect(containers).to eq({})
        expect(object_group.objects).to eq [user1]
      end
    end

    context "with nil" do
      let(:object) { nil }

      it "adds no objects" do
        expect(containers).to be_nil
        expect(object_group.objects).to eq []
      end
    end

    context "when many is true and the object is not a collection" do
      let(:object) { user1 }
      let(:many) { true }

      it "returns an Array with one container" do
        expect(containers).to eq [{}]
      end
    end

    context "when many is false and the object is a collection" do
      let(:many) { false }

      it "adds the collection as one object" do
        expect(containers).to eq({})
        expect(object_group.objects).to eq [[user1, user2]]
      end
    end

    context "with the :struct mode" do
      let(:mode) { :struct }

      it "returns an empty Struct per object" do
        struct_class = plan.result_builder(:struct).struct_class

        expect(containers).to eq [struct_class.new, struct_class.new]
        expect(containers[0]).not_to equal containers[1]
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
        containers

        expect(object_group.objects.map(&:name)).to eq ["Mr. Ann", "Mr. Bob"]
      end
    end
  end

  describe "#serialize" do
    subject(:serialize) { object_group.serialize }

    let!(:containers) { object_group.add([user1, user2], true) }

    it "fills the containers" do
      serialize

      expect(containers).to eq [{name: "Ann"}, {name: "Bob"}]
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

      it "adds the related objects to the group of the relation plan" do
        serialize

        child_group = run.object_group(plan.relation_points[0].child_plan)
        expect(child_group.objects).to eq [post]
        expect(containers).to eq [{name: "Ann", posts: child_group.containers}, {name: "Bob", posts: nil}]
      end
    end

    context "when an attribute raises an error" do
      let(:user_serializer) { Class.new(Serega) { attribute :name, value: proc { raise "boom" } } }

      it "adds the attribute name and the serializer to the error message" do
        expect { serialize }
          .to raise_error RuntimeError, "boom\n(when serializing 'name' attribute in #{user_serializer})"
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
