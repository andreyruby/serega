# frozen_string_literal: true

RSpec.describe Serega do
  describe ".attribute with block" do
    it "serializes the attribute value with a nested serializer defined by the block" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :first_name

        attribute :statistics, method: :itself do
          attribute :likes_count
          attribute :comments_count
        end
      end

      user = double(first_name: "Kate", likes_count: 10, comments_count: 3)

      expect(user_serializer.to_h(user)).to eq(
        first_name: "Kate",
        statistics: {likes_count: 10, comments_count: 3}
      )
    end

    it "serializes a relation found by attribute name" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :author do
          attribute :name
        end
      end

      user = double(author: double(name: "Kate"))
      expect(user_serializer.to_h(user)).to eq(author: {name: "Kate"})
    end

    it "serializes value found by the :value option" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :author, value: proc { |user| user.creator } do
          attribute :name
        end
      end

      user = double(creator: double(name: "Kate"))
      expect(user_serializer.to_h(user)).to eq(author: {name: "Kate"})
    end

    it "serializes enumerable values as arrays" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :posts do
          attribute :title
        end
      end

      user = double(posts: [double(title: "one"), double(title: "two")])
      expect(user_serializer.to_h(user)).to eq(posts: [{title: "one"}, {title: "two"}])
    end

    it "supports nested serialization modifiers same as regular relations" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :statistics, method: :itself do
          attribute :likes_count
          attribute :comments_count
        end
      end

      user = double(likes_count: 10, comments_count: 3)
      result = user_serializer.to_h(user, only: {statistics: [:likes_count]})
      expect(result).to eq(statistics: {likes_count: 10})
    end

    it "allows to define batch loaders inside the block" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :statistics, method: :itself do
          batch(:stats) do |users|
            users.to_h { |user| [user.id, {likes_count: user.id * 10}] }
          end

          attribute :likes_count, batch: :stats, value: proc { |user, batches:| batches[:stats][user.id][:likes_count] }
        end
      end

      user = double(id: 1)
      expect(user_serializer.to_h(user)).to eq(statistics: {likes_count: 10})
    end

    it "allows to register a preload handler inside the block" do
      preloaded = nil
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :author do
          preload_with { |objects, preloads| preloaded = [objects, preloads] }
          attribute :name, preload: :profile
        end
      end

      author = double(name: "Kate")
      user_serializer.to_h(double(author: author))
      expect(preloaded).to eq [[author], :profile]
    end

    it "auto-preloads the association same as with the :serializer option" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        config.auto_preload = {has_serializer_option: true}

        attribute :author do
          attribute :name
        end
      end

      expect(user_serializer.attributes[:author].preloads).to eq :author
    end

    it "prohibits to use block together with the :serializer option" do
      nested = Class.new(described_class)

      expect {
        Class.new(Serega) do
          attribute(:author, serializer: nested) { attribute :name }
        end
      }.to raise_error Serega::SeregaError, "Option :serializer can not be used together with block"
    end

    it "prohibits blocks with parameters, explaining the changed block behavior" do
      expect {
        Class.new(Serega) do
          attribute(:author) { |user| user.author }
        end
      }.to raise_error Serega::SeregaError, /use the `value: <callable>` option instead/
    end

    it "prohibits blocks that define no attributes, explaining the changed block behavior" do
      expect {
        Class.new(Serega) do
          config.base_serializer = Serega
          attribute(:full_name) { "Kate Smith" }
        end
      }.to raise_error Serega::SeregaError, /use the `value: <callable>` option instead/
    end

    it "raises instead of recursing when subclassing a serializer that is its own base and has a block attribute" do
      base = Class.new(described_class)
      base.config.base_serializer = base
      base.attribute(:meta, method: :itself) { attribute :version }

      expect { Class.new(base) }
        .to raise_error Serega::SeregaError, /cyclic definition/
    end

    it "serializes base serializer attributes together with attributes defined in the block" do
      base = Class.new(Serega) { attribute :id }
      user_serializer = Class.new(Serega) do
        config.base_serializer = base

        attribute :statistics, method: :itself do
          attribute :likes_count
        end
      end

      user = double(id: 1, likes_count: 10)
      expect(user_serializer.to_h(user)).to eq(statistics: {id: 1, likes_count: 10})
    end
  end
end
