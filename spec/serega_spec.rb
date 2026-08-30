# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe ".inherited" do
    it "inherits config" do
      parent_ser = Class.new(described_class)
      child_ser = Class.new(parent_ser)
      parent = parent_ser.config
      child = child_ser.config

      # Check config values are inherited
      expect(child.__send__(:opts)).to eq parent.__send__(:opts)
      expect(child.__send__(:opts)).not_to equal parent.__send__(:opts)

      # Check child config does not overwrite parent config values
      child.attribute_keys << :foo
      expect(parent.attribute_keys).not_to include :foo

      # Check child config does not adds new keys to parent config
      child.__send__(:opts)[:foo] = 123
      expect(parent.__send__(:opts)).not_to have_key(:foo)

      # Check child config is a subclass of parent config
      expect(child.class.superclass).to eq parent.class
    end

    it "inherits attributes" do
      parent = Class.new(described_class)
      parent.attribute(:foo)

      # Check attributes are copied to child attributes
      child = Class.new(parent)
      expect(child.attributes[:foo].class.superclass).to eq parent.attributes[:foo].class
    end

    it "inherits same batch loaders" do
      parent = Class.new(described_class)
      parent.batch(:foo, proc { |objects| objects })

      child = Class.new(parent)
      expect(child.batch_loaders).to have_key(:foo)
      expect(child.batch_loaders[:foo].load(1, nil)).to eq 1
    end

    it "inherits the preload_with handler" do
      handler = proc { |objects, preloads| [objects, preloads] }
      parent = Class.new(described_class)
      parent.preload_with(handler)

      child = Class.new(parent)
      expect(child.preload_with).to equal handler
    end

    it "allows child to override preload_with without affecting parent" do
      parent_handler = proc { |objects, preloads| :parent }
      child_handler = proc { |objects, preloads| :child }
      parent = Class.new(described_class)
      parent.preload_with(parent_handler)

      child = Class.new(parent)
      child.preload_with(child_handler)

      expect(child.preload_with).to equal child_handler
      expect(parent.preload_with).to equal parent_handler
    end

    it "inherits the prepare_initial_objects handler" do
      handler = proc { |objects| objects }
      parent = Class.new(described_class)
      parent.prepare_initial_objects(handler)

      child = Class.new(parent)
      expect(child.prepare_initial_objects).to equal handler
    end

    it "allows child to override prepare_initial_objects without affecting parent" do
      parent_handler = proc { |objects| :parent }
      child_handler = proc { |objects| :child }
      parent = Class.new(described_class)
      parent.prepare_initial_objects(parent_handler)

      child = Class.new(parent)
      child.prepare_initial_objects(child_handler)

      expect(child.prepare_initial_objects).to equal child_handler
      expect(parent.prepare_initial_objects).to equal parent_handler
    end

    it "inherits serialization class" do
      parent = Class.new(described_class)
      child = Class.new(parent)

      expect(child::SeregaObjectSerializer.superclass).to eq parent::SeregaObjectSerializer
    end
  end

  describe ".attribute" do
    it "adds new attribute" do
      attribute = serializer_class.attribute "foo"
      expect(serializer_class.attributes).to eq(foo: attribute)
    end
  end

  describe ".attributes" do
    it "returns empty hash when no attributes added" do
      expect(serializer_class.attributes).to eq({})
    end

    it "returns list of added attributes" do
      foo = serializer_class.attribute :foo
      bar = serializer_class.attribute :bar

      expect(serializer_class.attributes).to eq(foo: foo, bar: bar)
    end
  end

  describe "serialization" do
    subject(:result) { user_serializer.new(**modifiers).to_h(user, context: context) }

    let(:user_serializer) do
      Class.new(Serega) do
        attribute :first_name
        attribute :last_name
      end
    end
    let(:context) { {} }
    let(:modifiers) { {} }

    context "with empty array" do
      let(:user) { [] }

      it "returns empty array" do
        expect(result).to eq([])
      end
    end

    context "with object with attributes" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }

      it "returns hash" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with Struct object" do
      let(:user_struct) { Struct.new(:first_name, :last_name) }
      let(:user) { user_struct.new("FIRST_NAME", "LAST_NAME") }

      it "serializes Struct as a single object, not as a collection" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end

      it "wraps Struct in an array when :many option is true" do
        expect(user_serializer.to_h(user, many: true))
          .to eq([{first_name: "FIRST_NAME", last_name: "LAST_NAME"}])
      end
    end

    context "with Hash object" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, value: proc { |user| user[:first_name] }
          attribute :last_name, value: proc { |user| user[:last_name] }
        end
      end
      let(:user) { {first_name: "FIRST_NAME", last_name: "LAST_NAME"} }

      it "serializes Hash as a single object, not as a collection of key-value pairs" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with object with Struct relation" do
      let(:statistics_struct) { Struct.new(:likes_count, :comments_count) }
      let(:statistics_serializer) do
        Class.new(Serega) do
          attribute :likes_count
          attribute :comments_count
        end
      end

      let(:user) { double(statistics: statistics_struct.new(10, 20)) }
      let(:user_serializer) do
        child_serializer = statistics_serializer
        Class.new(Serega) do
          attribute :statistics, serializer: child_serializer
        end
      end

      it "serializes Struct relation as a single object, not as a collection" do
        expect(result).to eq({statistics: {likes_count: 10, comments_count: 20}})
      end
    end

    context "with object with relation" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      it "returns hash with relations" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT"}})
      end

      it "returns hash with relations when manually specifying :many option" do
        user_serializer.attribute :comment, serializer: comment_serializer, many: false
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT"}})
      end
    end

    context "with object with array relation" do
      let(:comments) { [double(text: "TEXT")] }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: comments) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comments, serializer: child_serializer
        end
      end

      it "returns hash with relations" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: [{text: "TEXT"}]})
      end

      it "returns hash with relations when manually specifying :many option" do
        user_serializer.attribute :comments, serializer: comment_serializer, many: true
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: [{text: "TEXT"}]})
      end
    end

    context "with object with hidden attribute" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name
        end
      end

      it "returns serialized object without hidden attributes" do
        expect(result).to eq({last_name: "LAST_NAME"})
      end
    end

    context "with `:with` context option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name
        end
      end

      let(:modifiers) { {with: :first_name} }

      it "returns specified in `:with` option hidden attributes" do
        expect(result).to include({first_name: "FIRST_NAME"})
      end
    end

    context "with `:only` context option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name
        end
      end

      let(:modifiers) { {only: :first_name} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({first_name: "FIRST_NAME"})
      end
    end

    context "with :except option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:modifiers) { {except: :first_name} }

      it "returns hash without :excepted attributes" do
        expect(result).to eq({last_name: "LAST_NAME"})
      end
    end

    context "with `:with` context option provided as Array" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name, hide: true
        end
      end

      let(:modifiers) { {with: %w[first_name last_name]} }

      it "returns specified in `:with` option hidden attributes" do
        expect(result).to include({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with `:only` context option provided as Array" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", middle_name: "MIDDLE_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name, hide: true
          attribute :middle_name
        end
      end

      let(:modifiers) { {only: %i[first_name last_name]} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with :except option provided as Array" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", middle_name: "MIDDLE_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :middle_name
        end
      end

      let(:modifiers) { {except: %i[first_name last_name]} }

      it "returns hash without :excepted attributes" do
        expect(result).to eq({middle_name: "MIDDLE_NAME"})
      end
    end

    context "with `:with` context option provided as Hash" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text, hide: true
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name, hide: true
          attribute :comment, serializer: child_serializer, hide: true
        end
      end

      let(:modifiers) { {with: {comment: :text}} }

      it "returns hash with additional attributes specified in `:with` option" do
        expect(result).to include({first_name: "FIRST_NAME", comment: {text: "TEXT"}})
      end
    end

    context "with `:only` context option provided as Hash" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {only: {comment: :text}} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({comment: {text: "TEXT"}})
      end
    end

    context "with :except option provided as Hash" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {except: {comment: :text}} }

      it "returns hash without excepted attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {}})
      end
    end

    context "with :except of relation" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {except: :comment} }

      it "returns hash without excepted attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with :only relation" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {only: :comment} }

      it "returns hash with only requested fields and all fields of requested relation" do
        expect(result).to eq({comment: {text: "TEXT"}})
      end
    end
  end
end
