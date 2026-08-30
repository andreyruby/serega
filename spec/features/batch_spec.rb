# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  describe "Batch functionality" do
    it "allows to specify named batch loader by providing callable value" do
      serializer_class.batch(:foo, proc { |objects| objects })
      block_result = serializer_class.batch_loaders[:foo].load(1, 2)
      expect(block_result).to eq 1
    end

    it "allows to specify named batch loader by providing block" do
      serializer_class.batch(:foo) { |objects, context| [objects, context] }
      block_result = serializer_class.batch_loaders[:foo].load(1, 2)
      expect(block_result).to eq [1, 2]
    end

    it "allows to specify named batch loader by providing block with objects and keyword ctx: parameters" do
      serializer_class.batch(:foo) { |objects, ctx:| [objects, ctx] }
      block_result = serializer_class.batch_loaders[:foo].load(1, 2)
      expect(block_result).to eq [1, 2]
    end

    it "serializes attribute with `batch: <loader_name>` short form using default value resolution" do
      serializer_class.batch(:stats) { |users| users.to_h { |user| [user.id, user.id * 10] } }
      serializer_class.attribute(:likes_count, batch: :stats)

      user = double(id: 1)
      expect(serializer_class.to_h(user)).to eq(likes_count: 10)
    end

    it "serializes attribute with String `batch: <loader_name>` short form" do
      serializer_class.batch(:stats) { |users| users.to_h { |user| [user.id, user.id * 10] } }
      serializer_class.attribute(:likes_count, batch: "stats")

      user = double(id: 2)
      expect(serializer_class.to_h(user)).to eq(likes_count: 20)
    end

    it "checks only block or only value provided" do
      # no block and no value
      expect { serializer_class.batch(:foo) }
        .to raise_error(Serega::SeregaError, "Batch loader must be defined with a callable value or block")

      # block and value together
      expect { serializer_class.batch(:foo, proc {}) {} }
        .to raise_error(Serega::SeregaError, "Batch loader must be defined with a callable value or block")
    end

    context "when same named batch loader is used by multiple attributes" do
      subject(:result) { user_serializer.to_h([user1, user2], many: true) }

      let(:load_calls) { [] }
      let(:user1) { double(id: 1) }
      let(:user2) { double(id: 2) }

      let(:user_serializer) do
        calls = load_calls
        Class.new(Serega) do
          batch(:stats) do |objects|
            calls << objects.map(&:id)
            objects.each_with_object({}) { |obj, hash| hash[obj.id] = {comments: obj.id * 10, likes: obj.id * 100} }
          end

          attribute(:comments_count, batch: {use: :stats}, value: proc { |obj, batches:| batches[:stats][obj.id][:comments] })
          attribute(:likes_count, batch: {use: :stats}, value: proc { |obj, batches:| batches[:stats][obj.id][:likes] })
        end
      end

      it "loads the shared batch only once" do
        expect(result).to eq [
          {comments_count: 10, likes_count: 100},
          {comments_count: 20, likes_count: 200}
        ]
        expect(load_calls).to eq [[1, 2]]
      end
    end

    context "when serialized objects are a non-Array enumerable" do
      let(:user_serializer) do
        Class.new(Serega) do
          batch(:stats) { |users| users.each_with_object({}) { |user, hash| hash[user.id] = user.id * 10 } }
          attribute(:stat, batch: {use: :stats}, value: proc { |user, batches:| batches[:stats][user.id] })
        end
      end

      it "batch loads objects gathered from the enumerable" do
        users = [double(id: 1), double(id: 2)].each # Enumerator, not an Array
        expect(user_serializer.to_h(users, many: true)).to eq [{stat: 10}, {stat: 20}]
      end
    end

    context "when many: true but a sole object is given" do
      it "wraps the object in an array instead of raising (:many serialization option)" do
        user_serializer = Class.new(Serega) { attribute :id }
        expect(user_serializer.to_h(double(id: 1), many: true)).to eq [{id: 1}]
      end

      it "wraps a sole relation object in an array (:many attribute option)" do
        comment_serializer = Class.new(Serega) { attribute :id }
        user_serializer = Class.new(Serega) do
          attribute :comments, serializer: comment_serializer, many: true
        end
        user = double(comments: double(id: 5)) # a sole object, not a collection
        expect(user_serializer.to_h(user)).to eq(comments: [{id: 5}])
      end
    end

    context "with some error in batch loader" do
      subject(:result) { user_serializer.to_h(user) }

      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, batch: proc { |_user| foo } # not existing variable call
        end
      end

      let(:user) { double }

      it "raises error with specified attribute name and serializer class" do
        expect { result }.to raise_error NameError,
          end_with("(when serializing 'first_name' attribute in #{user_serializer})")
      end
    end
  end
end
