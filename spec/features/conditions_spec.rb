# frozen_string_literal: true

RSpec.describe Serega do
  describe "conditional attributes" do
    subject(:result) { user_serializer.public_send(serialization_method, users, context: context) }

    let(:serialization_method) { :to_h }
    let(:context) { {} }
    let(:user_class) { Struct.new(:id, :name, :email, :age, :admin, :posts, :avatar) }
    let(:post_class) { Struct.new(:title) }
    let(:avatar_class) { Struct.new(:url) }
    let(:post_serializer) { Class.new(Serega) { attribute :title }.freeze }
    let(:avatar_serializer) { Class.new(Serega) { attribute :url }.freeze }

    describe ":if and :unless" do
      context "with :if and :unless conditions" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :email, if: :admin
            attribute :name, unless: :admin
            freeze
          end
        end

        let(:users) do
          [
            user_class.new(name: "Ann", email: "ann@example.com", admin: true),
            user_class.new(name: "Bob", email: "bob@example.com", admin: false)
          ]
        end

        it "omits the attributes of the users that fail the conditions" do
          expect(result).to eq [{email: "ann@example.com"}, {name: "Bob"}]
        end
      end

      context "with a condition that reads the context" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :email, if: proc { |_user, context| context[:show_emails] }
            freeze
          end
        end

        let(:users) { [user_class.new(email: "ann@example.com")] }
        let(:context) { {show_emails: true} }

        it "passes the serialization context to the condition" do
          expect(result).to eq [{email: "ann@example.com"}]
        end
      end

      context "when a condition skips an attribute of the first user only" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :name
            attribute :email, if: :admin
            attribute :age
            freeze
          end
        end

        let(:users) { [user_class.new(admin: false), user_class.new(admin: true)] }

        it "keeps the attributes in definition order" do
          expect(result.map(&:keys)).to eq [%i[name age], %i[name email age]]
        end
      end
    end

    describe ":if_value and :unless_value" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :age, if_value: proc { |age| age >= 18 }
          attribute :name, unless_value: :empty?
          freeze
        end
      end

      let(:users) { [user_class.new(name: "", age: 30), user_class.new(name: "Bob", age: 12)] }

      it "omits the attributes whose values fail the conditions" do
        expect(result).to eq [{age: 30}, {name: "Bob"}]
      end
    end

    describe "relations" do
      context "with a conditional collection relation" do
        let(:user_serializer) do
          posts = post_serializer

          Class.new(Serega) do
            attribute :posts, serializer: posts, unless: :admin
            freeze
          end
        end

        let(:users) { [user_class.new(admin: true), user_class.new(admin: false, posts: [post_class.new("Hello")])] }

        it "omits the skipped relation" do
          expect(result).to eq [{}, {posts: [{title: "Hello"}]}]
        end
      end

      context "with a conditional single relation" do
        let(:user_serializer) do
          avatar = avatar_serializer

          Class.new(Serega) do
            attribute :avatar, serializer: avatar, if: :admin
            freeze
          end
        end

        let(:users) do
          [
            user_class.new(admin: true, avatar: avatar_class.new("ann.png")),
            user_class.new(admin: false, avatar: avatar_class.new("bob.png")),
            user_class.new(admin: true, avatar: nil)
          ]
        end

        it "omits the skipped relation and keeps the nil relation" do
          expect(result).to eq [{avatar: {url: "ann.png"}}, {}, {avatar: nil}]
        end
      end

      context "with conditions in the related serializer" do
        let(:user_serializer) do
          avatar = Class.new(Serega) { attribute :url, unless_value: proc { |url| url == "bob.png" } }.freeze

          Class.new(Serega) do
            attribute :avatar, serializer: avatar
            freeze
          end
        end

        let(:users) { [user_class.new(avatar: avatar_class.new("ann.png")), user_class.new(avatar: avatar_class.new("bob.png"))] }

        it "omits the skipped attributes of the related objects" do
          expect(result).to eq [{avatar: {url: "ann.png"}}, {avatar: {}}]
        end
      end
    end

    describe "batch loaders" do
      context "with conditional batch attributes" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :online_time, if: :admin, batch: proc { |_users| {1 => 10, 2 => 20} }
            attribute :score, unless_value: proc { |score| score == 200 }, batch: proc { |_users| {1 => 100, 2 => 200} }
            freeze
          end
        end

        let(:users) { [user_class.new(id: 1, admin: false), user_class.new(id: 2, admin: true)] }

        it "omits the batch attributes that fail the conditions" do
          expect(result).to eq [{score: 100}, {online_time: 20}]
        end
      end

      context "with a conditional batch relation" do
        let(:user_serializer) do
          avatar = avatar_serializer
          bob_avatar = avatar_class.new("bob.png")

          Class.new(Serega) do
            attribute :avatar, serializer: avatar, if: :admin, batch: proc { |_users| {2 => bob_avatar} }
            freeze
          end
        end

        let(:users) { [user_class.new(id: 1, admin: false), user_class.new(id: 2, admin: true)] }

        it "omits the skipped relation" do
          expect(result).to eq [{}, {avatar: {url: "bob.png"}}]
        end
      end
    end

    describe "Data and Struct objects" do
      let(:user_serializer) do
        posts = post_serializer

        Class.new(Serega) do
          attribute :email, if: :admin
          attribute :age, if_value: proc { |age| age >= 18 }
          attribute :posts, serializer: posts, unless: :admin
          freeze
        end
      end

      let(:users) do
        [
          user_class.new(email: "ann@example.com", age: 30, admin: true),
          user_class.new(email: "bob@example.com", age: 12, admin: false, posts: [])
        ]
      end

      let(:serialized_values) do
        [
          {email: "ann@example.com", age: 30, posts: nil},
          {email: nil, age: nil, posts: []}
        ]
      end

      context "with to_data" do
        let(:serialization_method) { :to_data }

        it "returns objects of one Data class with nil for the skipped attributes" do
          expect(result.map(&:to_h)).to eq serialized_values
          expect(result.map(&:class).uniq).to eq [user_serializer::SeregaResultBuilder.data_class_for(%i[email age posts])]
        end
      end

      context "with to_struct" do
        let(:serialization_method) { :to_struct }

        it "returns objects of one Struct class with nil for the skipped attributes" do
          expect(result.map(&:to_h)).to eq serialized_values
          expect(result.map(&:class).uniq).to eq [user_serializer::SeregaResultBuilder.struct_class_for(%i[email age posts])]
        end
      end
    end

    describe "errors" do
      let(:users) { [user_class.new] }

      context "when a condition raises" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :email, if: proc { raise "boom in condition" }
            freeze
          end
        end

        it "adds the condition, the attribute and its location to the error message" do
          location = user_serializer.attributes[:email].location

          expect { result }
            .to raise_error RuntimeError, "boom in condition\n(when checking the :if condition of the 'email' attribute in #{user_serializer}, #{location})"
        end
      end

      context "when a value condition raises" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :email, if_value: proc { raise "boom in condition" }
            freeze
          end
        end

        it "adds the condition, the attribute and its location to the error message" do
          location = user_serializer.attributes[:email].location

          expect { result }
            .to raise_error RuntimeError, "boom in condition\n(when checking the :if_value condition of the 'email' attribute in #{user_serializer}, #{location})"
        end
      end

      context "when a conditional attribute raises" do
        let(:user_serializer) do
          Class.new(Serega) do
            attribute :email, value: proc { raise "boom in value" }, if: proc { true }
            freeze
          end
        end

        it "adds the attribute and its location to the error message" do
          location = user_serializer.attributes[:email].location

          expect { result }
            .to raise_error RuntimeError, "boom in value\n(when serializing the 'email' attribute in #{user_serializer}, #{location})"
        end
      end

      context "when a condition of a relation raises" do
        let(:user_serializer) do
          avatar = avatar_serializer

          Class.new(Serega) do
            attribute :avatar, serializer: avatar, unless: proc { raise "boom in condition" }
            freeze
          end
        end

        it "adds the condition, the attribute and its location to the error message" do
          location = user_serializer.attributes[:avatar].location

          expect { result }
            .to raise_error RuntimeError, "boom in condition\n(when checking the :unless condition of the 'avatar' attribute in #{user_serializer}, #{location})"
        end
      end

      context "when a conditional relation raises" do
        let(:user_serializer) do
          avatar = avatar_serializer

          Class.new(Serega) do
            attribute :avatar, serializer: avatar, value: proc { raise "boom in relation" }, if: proc { true }
            freeze
          end
        end

        it "adds the attribute and its location to the error message" do
          location = user_serializer.attributes[:avatar].location

          expect { result }
            .to raise_error RuntimeError, "boom in relation\n(when serializing the 'avatar' attribute in #{user_serializer}, #{location})"
        end
      end
    end
  end
end
