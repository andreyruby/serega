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

    context "with `batch: <loader_name>` short form" do
      let(:serializer_class) do
        Class.new(described_class) do
          batch(:stats) { |users| users.to_h { |user| [user.id, user.id * 10] } }
          attribute(:likes_count, batch: :stats)
          attribute(:views_count, batch: "stats")
          freeze
        end
      end

      it "serializes attributes with Symbol and String loader names using default value resolution" do
        user = double(id: 1)
        expect(serializer_class.to_h(user)).to eq(likes_count: 10, views_count: 10)
      end
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
          freeze
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
          freeze
        end
      end

      it "batch loads objects gathered from the enumerable" do
        users = [double(id: 1), double(id: 2)].each # Enumerator, not an Array
        expect(user_serializer.to_h(users, many: true)).to eq [{stat: 10}, {stat: 20}]
      end
    end

    context "when many: true but a sole object is given" do
      it "wraps the object in an array instead of raising (:many serialization option)" do
        user_serializer = Class.new(Serega) { attribute :id }.freeze
        expect(user_serializer.to_h(double(id: 1), many: true)).to eq [{id: 1}]
      end

      it "wraps a sole relation object in an array (:many attribute option)" do
        comment_serializer = Class.new(Serega) { attribute :id }.freeze
        user_serializer = Class.new(Serega) do
          attribute :comments, serializer: comment_serializer, many: true
          freeze
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
          freeze
        end
      end

      let(:user) { double }

      it "raises error with specified attribute name and serializer class" do
        expect { result }.to raise_error NameError,
          end_with("(when serializing the 'first_name' attribute in #{user_serializer}, #{user_serializer.attributes[:first_name].location})")
      end
    end

    context "with an inline batch loader and a named batch loader of the same name" do
      let(:user_serializer) do
        Class.new(Serega) do
          batch(:rating) { |users| users.to_h { |user| [user.id, :named] } }
          attribute :rating, batch: ->(users) { users.to_h { |user| [user.id, :inline] } }
          attribute :score, batch: :rating
          freeze
        end
      end

      let(:user) { double(id: 1) }

      it "keeps the named batch loader for other attributes" do
        expect(user_serializer.to_h(user)).to eq(rating: :inline, score: :named)
        expect(user_serializer.batch_loaders[:rating].block).not_to eq user_serializer.attributes[:rating].inline_batch_loader.block
      end
    end

    context "with an inline batch loader and a :value option" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :rating,
            batch: ->(users) { users.to_h { |user| [user.id, 5] } },
            value: proc { |user, batches:| batches[:rating][user.id] * 2 }
          freeze
        end
      end

      let(:user) { double(id: 1) }

      it "passes the loaded batch to the :value option" do
        expect(user_serializer.to_h(user)).to eq(rating: 10)
      end
    end

    context "with a child serializer of a serializer with an inline batch loader" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :rating, batch: ->(users) { users.to_h { |user| [user.id, 5] } }
          freeze
        end
      end

      let(:child_serializer) { Class.new(user_serializer).freeze }
      let(:user) { double(id: 1) }

      it "serializes the attribute with the inline loader" do
        expect(child_serializer.to_h(user)).to eq(rating: 5)
        expect(child_serializer.batch_loaders).to be_empty
      end
    end

    context "with a child serializer of a serializer with a named batch loader" do
      subject(:result) { child_serializer.to_h(user) }

      let(:user_serializer) do
        Class.new(Serega) do
          batch(:stats) { |users| users.to_h { |user| [user.id, user.id * 10] } }
          attribute :likes_count, batch: :stats
          freeze
        end
      end

      let(:child_serializer) { Class.new(user_serializer).freeze }
      let(:user) { double(id: 1) }

      it "serializes the attribute with the loader of the parent" do
        expect(result).to eq(likes_count: 10)
      end
    end

    context "when a child serializer redefines the batch loader" do
      let(:user_serializer) do
        Class.new(Serega) do
          batch(:stats) { |users| users.to_h { |user| [user.id, user.id * 10] } }
          attribute :likes_count, batch: :stats
          freeze
        end
      end

      let(:child_serializer) do
        Class.new(user_serializer) do
          batch(:stats) { |users| users.to_h { |user| [user.id, user.id * 100] } }
          freeze
        end
      end

      let(:user) { double(id: 1) }

      it "serializes the attribute of each serializer with its own loader" do
        expect(child_serializer.to_h(user)).to eq(likes_count: 100)
        expect(user_serializer.to_h(user)).to eq(likes_count: 10)
      end
    end
  end
end
