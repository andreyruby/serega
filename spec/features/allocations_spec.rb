# frozen_string_literal: true

require "support/matchers/allocate_objects"

# A serialization allocates the serialized objects and a fixed number of
# Arrays and run objects. Keyword arguments, options and calls of the user
# blocks allocate nothing.
#
# The counts hold on CRuby 4.0 and later: older versions allocate more for
# some calls, for example an Array for each `...` argument forwarding on 3.3.
RSpec.describe Serega, if: RUBY_ENGINE == "ruby" && RUBY_VERSION >= "4.0" do
  subject(:serialize) { -> { prepared.to_h(object, context: context, many: many) } }

  let(:object) { users }
  let(:many) { true }
  let(:record_class) { Data.define(:id, :name, :posts) }
  let(:posts) { [record_class.new(id: 3, name: "Post", posts: [])].freeze }
  let(:users) { [record_class.new(id: 1, name: "Ann", posts: posts), record_class.new(id: 2, name: "Bob", posts: posts)].freeze }
  let(:context) { {admin: true}.freeze }
  let(:prepared) { serializer.new }

  context "with plain attributes" do
    let(:serializer) do
      Class.new(described_class) do
        attribute :id
        attribute :name
      end
    end

    it "allocates the serialized Hashes, the sources and the serialized Array" do
      expect(serialize).to allocate_objects(T_HASH: 2, T_ARRAY: 2)
    end

    context "with one object" do
      let(:object) { users[0] }
      let(:many) { false }

      it "allocates only the serialized Hash" do
        expect(serialize).to allocate_objects(T_HASH: 1)
      end
    end
  end

  context "with blocks that take the context" do
    let(:serializer) do
      Class.new(described_class) do
        prepare_initial_objects { |objects, ctx:| objects }
        formatter :same, proc { |value, ctx:| value }
        attribute :id, value: proc { |user, ctx:| user.id }, format: :same
        attribute :name, value: proc { |user, ctx| user.name }, if: proc { |_user, ctx:| ctx[:admin] }
      end
    end

    it "allocates the serialized Hashes, the sources and the serialized Array" do
      expect(serialize).to allocate_objects(T_HASH: 2, T_ARRAY: 2)
    end
  end

  context "with batch loaders" do
    let(:serializer) do
      names = {1 => "Ann", 2 => "Bob"}.freeze

      Class.new(described_class) do
        batch(:names) { |_users, ctx:| names }
        attribute :name, batch: :names
        attribute :upname, batch: {use: :names}, value: proc { |user, ctx:, batches:| batches[:names][user.id] }
      end
    end

    it "allocates the run, its source group, the loaded batches and the Arrays of the run" do
      expect(serialize).to allocate_objects(T_OBJECT: 2, T_HASH: 5, T_ARRAY: 7)
    end
  end

  context "with a relation" do
    let(:serializer) do
      post_serializer = Class.new(described_class) { attribute :id }

      Class.new(described_class) do
        attribute :posts, serializer: post_serializer, many: true
      end
    end

    it "allocates the run, its source groups, the relation values and the Arrays of the run" do
      expect(serialize).to allocate_objects(T_OBJECT: 4, T_HASH: 5, T_ARRAY: 12)
    end
  end

  context "with a formatted attribute" do
    let(:serializer) do
      Class.new(described_class) do
        attribute :id, format: [:to_s]
      end
    end

    it "allocates the serialized Hashes, the formatted values, the sources and the serialized Array" do
      expect(serialize).to allocate_objects(T_HASH: 2, T_STRING: 2, T_ARRAY: 2)
    end
  end

  context "with a relation to one object and a relation to many objects" do
    let(:serializer) do
      post_serializer = Class.new(described_class) { attribute :id }

      Class.new(described_class) do
        attribute :author, serializer: post_serializer, many: false, method: :itself
        attribute :posts, serializer: post_serializer, many: true
      end
    end

    it "allocates the run, its source groups, the relation values and the Arrays of the run" do
      expect(serialize).to allocate_objects(T_OBJECT: 5, T_HASH: 7, T_ARRAY: 17)
    end
  end

  context "with a presenter" do
    let(:serializer) do
      Class.new(described_class) do
        presenter do
          def title
            name
          end
        end

        attribute :title
      end
    end

    it "allocates the run, its source group, a presenter per object and the Arrays of the run" do
      expect(serialize).to allocate_objects(T_OBJECT: 4, T_HASH: 2, T_ARRAY: 5)
    end
  end

  context "with the root plugin" do
    let(:serializer) do
      Class.new(described_class) do
        plugin :root
        attribute :id
      end
    end

    it "allocates the root Hash and the Hash of the plugin options" do
      expect(serialize).to allocate_objects(T_HASH: 4, T_ARRAY: 2)
    end
  end

  context "with the metadata plugin" do
    let(:serializer) do
      Class.new(described_class) do
        plugin :root
        plugin :metadata
        meta_attribute(:version) { 1 }
        attribute :id
      end
    end

    it "allocates the root Hash, the Hash of the plugin options and the metadata Hash" do
      expect(serialize).to allocate_objects(T_HASH: 5, T_ARRAY: 2)
    end
  end
end
