# frozen_string_literal: true

RSpec.describe Serega do
  let(:post_class) { Struct.new(:title) }
  let(:user_class) { Struct.new(:name, :post) }
  let(:user) { user_class.new("Bruce", post_class.new("Hello")) }

  let(:post_serializer) do
    Class.new(described_class) do
      attribute :title
      freeze
    end
  end

  let(:user_serializer) do
    posts = post_serializer

    Class.new(described_class) do
      attribute :name
      attribute :post, serializer: posts
      freeze
    end
  end

  describe ".freeze" do
    it "returns the frozen serializer" do
      serializer = Class.new(described_class) { attribute :name }

      expect(serializer.freeze).to be serializer
      expect(serializer).to be_frozen
    end

    context "when the serializer is frozen" do
      let(:serializer) { Class.new(described_class) { attribute :name }.freeze }

      it "returns the serializer" do
        expect(serializer.freeze).to be serializer
      end
    end
  end

  context "when the serializer is not frozen" do
    let(:user_serializer) { Class.new(described_class) { attribute :name } }

    it "raises a SeregaError on serialization" do
      expect { user_serializer.to_h(user) }
        .to raise_error Serega::SeregaError, "#{user_serializer} is not frozen. Call `freeze` at the end of its definition"
    end
  end

  context "when a relation serializer is not frozen" do
    let(:post_serializer) { Class.new(described_class) { attribute :title } }

    it "raises a SeregaError that names the relation serializer" do
      expect { user_serializer.to_h(user) }
        .to raise_error Serega::SeregaError, "#{post_serializer} is not frozen. Call `freeze` at the end of its definition"
    end
  end

  context "with a nested serializer defined with a block" do
    let(:user_serializer) do
      Class.new(described_class) do
        config.base_serializer = Serega
        attribute(:post) { attribute :title }
        freeze
      end
    end

    it "freezes the nested serializer when its block ends" do
      expect(user_serializer.attributes[:post].serializer).to be_frozen
      expect(user_serializer.to_h(user)).to eq(post: {title: "Hello"})
    end
  end

  context "when the serializer is frozen" do
    def frozen_error(serializer)
      "#{serializer} can not be changed after it was frozen"
    end

    describe ".attribute" do
      it "raises a SeregaError" do
        expect { user_serializer.attribute :email }.to raise_error Serega::SeregaError, frozen_error(user_serializer)
      end
    end

    describe ".plugin" do
      it "raises a SeregaError" do
        expect { user_serializer.plugin :root }.to raise_error Serega::SeregaError, frozen_error(user_serializer)
      end
    end

    describe ".batch" do
      it "raises a SeregaError" do
        expect { user_serializer.batch(:posts) { |_users| {} } }
          .to raise_error Serega::SeregaError, frozen_error(user_serializer)
      end
    end

    describe ".preload_with" do
      context "with a block" do
        it "raises a SeregaError" do
          expect { user_serializer.preload_with { |_objects, _preloads| } }
            .to raise_error Serega::SeregaError, frozen_error(user_serializer)
        end
      end

      context "without a block" do
        it "returns nil" do
          expect(user_serializer.preload_with).to be_nil
        end
      end
    end

    describe ".prepare_initial_objects" do
      context "with a block" do
        it "raises a SeregaError" do
          expect { user_serializer.prepare_initial_objects { |objects| objects } }
            .to raise_error Serega::SeregaError, frozen_error(user_serializer)
        end
      end

      context "without a block" do
        it "returns nil" do
          expect(user_serializer.prepare_initial_objects).to be_nil
        end
      end
    end

    describe ".presenter" do
      context "with a block" do
        it "raises a SeregaError" do
          expect { user_serializer.presenter { def name = "Batman" } }
            .to raise_error Serega::SeregaError, frozen_error(user_serializer)
        end
      end

      context "without a block" do
        it "returns nil" do
          expect(user_serializer.presenter).to be_nil
        end
      end
    end

    describe ".meta_attribute" do
      let(:user_serializer) do
        Class.new(described_class) do
          plugin :root
          plugin :metadata

          attribute :name
          freeze
        end
      end

      it "raises a SeregaError" do
        expect { user_serializer.meta_attribute(:version, const: 1) }
          .to raise_error Serega::SeregaError, frozen_error(user_serializer)
      end
    end

    describe ".config" do
      it "raises a FrozenError on a change" do
        expect { user_serializer.config.hide_by_default = true }.to raise_error FrozenError
      end

      context "with a string config value" do
        let(:user_serializer) do
          Class.new(described_class) do
            plugin :root, root: +"user"

            attribute :name
            freeze
          end
        end

        it "raises a FrozenError on a change of the string" do
          expect { user_serializer.config.root.one << "s" }.to raise_error FrozenError
        end
      end
    end

    context "with a subclass of the serializer" do
      let(:child_serializer) do
        Class.new(user_serializer) do
          plugin :root
          config.root.one = :user
          attribute :name_length, value: proc { |user| user.name.length }
          freeze
        end
      end

      it "accepts new plugins, config and attributes in the subclass" do
        expect(child_serializer.call(user)).to eq(user: {name: "Bruce", post: {title: "Hello"}, name_length: 5})
      end
    end
  end
end
