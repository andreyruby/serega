# frozen_string_literal: true

RSpec.describe Serega do
  context "when the serializer was used for serialization" do
    let(:post_class) { Struct.new(:title) }
    let(:user_class) { Struct.new(:name, :post) }
    let(:user) { user_class.new("Bruce", post_class.new("Hello")) }

    let(:post_serializer) { Class.new(described_class) { attribute :title } }

    let(:user_serializer) do
      posts = post_serializer

      Class.new(described_class) do
        attribute :name
        attribute :post, serializer: posts
      end
    end

    before { user_serializer.call(user) }

    def locked_error(serializer)
      "#{serializer} can not be changed after it was used for serialization"
    end

    describe ".attribute" do
      it "raises a SeregaError on the serializer and on its nested serializer" do
        expect { user_serializer.attribute :email }.to raise_error Serega::SeregaError, locked_error(user_serializer)

        expect { post_serializer.attribute :body }.to raise_error Serega::SeregaError, locked_error(post_serializer)
      end
    end

    describe ".plugin" do
      it "raises a SeregaError" do
        expect { user_serializer.plugin :root }.to raise_error Serega::SeregaError, locked_error(user_serializer)
      end
    end

    describe ".batch" do
      it "raises a SeregaError" do
        expect { user_serializer.batch(:posts) { |_users| {} } }
          .to raise_error Serega::SeregaError, locked_error(user_serializer)
      end
    end

    describe ".preload_with" do
      context "with a block" do
        it "raises a SeregaError" do
          expect { user_serializer.preload_with { |_objects, _preloads| } }
            .to raise_error Serega::SeregaError, locked_error(user_serializer)
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
            .to raise_error Serega::SeregaError, locked_error(user_serializer)
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
            .to raise_error Serega::SeregaError, locked_error(user_serializer)
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
        end
      end

      it "raises a SeregaError" do
        expect { user_serializer.meta_attribute(:version, const: 1) }
          .to raise_error Serega::SeregaError, locked_error(user_serializer)
      end
    end

    describe ".config" do
      it "raises a FrozenError on a change of the serializer and of its nested serializer" do
        expect { user_serializer.config.hide_by_default = true }.to raise_error FrozenError

        expect { post_serializer.config.max_cached_plans_per_serializer_count = 10 }.to raise_error FrozenError
      end

      context "with a string config value" do
        let(:user_serializer) do
          Class.new(described_class) do
            plugin :root, root: +"user"

            attribute :name
          end
        end

        it "raises a FrozenError on a change of the string" do
          expect { user_serializer.config.root.one << "s" }.to raise_error FrozenError
        end
      end
    end

    context "with a subclass of the serializer" do
      let(:child_serializer) { Class.new(user_serializer) }

      it "accepts new plugins, config and attributes in the subclass" do
        child_serializer.plugin :root
        child_serializer.config.root.one = :user
        child_serializer.attribute :name_length, value: proc { |user| user.name.length }

        expect(child_serializer.call(user)).to eq(user: {name: "Bruce", post: {title: "Hello"}, name_length: 5})
      end
    end
  end
end
