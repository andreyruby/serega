# frozen_string_literal: true

RSpec.describe Serega do
  describe "changing a serializer after it was used for serialization" do
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

    it "raises when adding an attribute" do
      expect { user_serializer.attribute :email }.to raise_error Serega::SeregaError, locked_error(user_serializer)
    end

    it "raises when adding an attribute to a nested serializer" do
      expect { post_serializer.attribute :body }.to raise_error Serega::SeregaError, locked_error(post_serializer)
    end

    it "raises when loading a plugin" do
      expect { user_serializer.plugin :root }.to raise_error Serega::SeregaError, locked_error(user_serializer)
    end

    it "raises when defining a batch loader" do
      expect { user_serializer.batch(:posts) { |_users| {} } }
        .to raise_error Serega::SeregaError, locked_error(user_serializer)
    end

    it "raises when registering handlers" do
      expect { user_serializer.preload_with { |_objects, _preloads| } }
        .to raise_error Serega::SeregaError, locked_error(user_serializer)
      expect { user_serializer.prepare_initial_objects { |objects| objects } }
        .to raise_error Serega::SeregaError, locked_error(user_serializer)
    end

    it "raises when defining presenter methods" do
      expect { user_serializer.presenter { def name = "Batman" } }
        .to raise_error Serega::SeregaError, locked_error(user_serializer)
    end

    it "raises when adding a meta attribute" do
      metadata_serializer = Class.new(described_class) do
        plugin :root
        plugin :metadata
      end
      metadata_serializer.call(user)

      expect { metadata_serializer.meta_attribute(:version, const: 1) }
        .to raise_error Serega::SeregaError, locked_error(metadata_serializer)
    end

    it "returns registered handlers and presenter" do
      expect(user_serializer.preload_with).to be_nil
      expect(user_serializer.prepare_initial_objects).to be_nil
      expect(user_serializer.presenter).to be_nil
    end

    it "raises when changing config" do
      expect { user_serializer.config.hide_by_default = true }.to raise_error FrozenError
      expect { post_serializer.config.max_cached_plans_per_serializer_count = 10 }.to raise_error FrozenError
    end

    it "freezes config strings" do
      root_serializer = Class.new(described_class) { plugin :root, root: +"user" }
      root_serializer.call(user)

      expect { root_serializer.config.root.one << "s" }.to raise_error FrozenError
    end

    it "allows changing a subclass" do
      child_serializer = Class.new(user_serializer)
      child_serializer.plugin :root
      child_serializer.config.root.one = :user
      child_serializer.attribute :name_length, value: proc { |user| user.name.length }

      expect(child_serializer.call(user)).to eq(user: {name: "Bruce", post: {title: "Hello"}, name_length: 5})
    end
  end
end
