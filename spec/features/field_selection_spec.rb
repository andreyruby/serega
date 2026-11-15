# frozen_string_literal: true

RSpec.describe Serega do
  describe "serialization" do
    subject(:result) { user_serializer.new(**selection).to_h(user, context: context) }

    let(:user_serializer) do
      Class.new(Serega) do
        attribute :first_name
        attribute :last_name
      end
    end

    let(:context) { {} }
    let(:selection) { {} }

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

      let(:selection) { {with: :first_name} }

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

      let(:selection) { {only: :first_name} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({first_name: "FIRST_NAME"})
      end
    end

    context "with :except option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:selection) { {except: :first_name} }

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

      let(:selection) { {with: %w[first_name last_name]} }

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

      let(:selection) { {only: %i[first_name last_name]} }

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

      let(:selection) { {except: %i[first_name last_name]} }

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

      let(:selection) { {with: {comment: :text}} }

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

      let(:selection) { {only: {comment: :text}} }

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

      let(:selection) { {except: {comment: :text}} }

      it "returns hash without excepted attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {}})
      end
    end

    context "with :except option provided as an Array with a Hash" do
      let(:comment) { double(text: "TEXT", likes_count: 10) }

      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
          attribute :likes_count
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

      let(:selection) { {except: [:first_name, comment: :text]} }

      it "returns hash without excepted attributes" do
        expect(result).to eq({last_name: "LAST_NAME", comment: {likes_count: 10}})
      end
    end

    context "with `:with` context option provided as an Array with a Hash" do
      let(:comment) { double(text: "TEXT", likes_count: 10) }

      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text, hide: true
          attribute :likes_count
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

      let(:selection) { {with: [:last_name, comment: :text]} }

      it "returns hash with additional attributes specified in `:with` option" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT", likes_count: 10}})
      end
    end

    context "with `:only` context option naming a hidden attribute of a hidden relation" do
      let(:comment) { double(text: "TEXT") }

      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text, hide: true
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", comment: comment) }

      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :comment, serializer: child_serializer, hide: true
        end
      end

      let(:selection) { {only: {comment: :text}} }

      it "returns hash with the hidden attribute only" do
        expect(result).to eq({comment: {text: "TEXT"}})
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

      let(:selection) { {except: :comment} }

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

      let(:selection) { {only: :comment} }

      it "returns hash with only requested fields and all fields of requested relation" do
        expect(result).to eq({comment: {text: "TEXT"}})
      end
    end

    context "with :except of an attribute and :only of relation fields" do
      let(:comment) { double(text: "TEXT", author: "AUTHOR") }

      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
          attribute :author
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

      let(:selection) { {except: :last_name, only: {comment: :text}} }

      it "returns the other attributes and only the requested relation fields" do
        expect(result).to eq({first_name: "FIRST_NAME", comment: {text: "TEXT"}})
      end
    end

    context "with options that change on each of three levels" do
      let(:friend_of_friend) { double(first_name: "Alfred", last_name: "Pennyworth") }
      let(:friend) { double(first_name: "Selina", last_name: "Kyle", friend: friend_of_friend) }
      let(:user) { double(first_name: "Bruce", last_name: "Wayne", friend: friend) }

      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :friend, serializer: self, hide: true
        end
      end

      let(:selection) { {only: [:first_name, {friend: {friend: :last_name}}], except: {friend: :first_name}} }

      it "selects the fields of each level with its own option" do
        expect(result).to eq({first_name: "Bruce", friend: {last_name: "Kyle", friend: {last_name: "Pennyworth"}}})
      end
    end

    context "with options given as Strings" do
      let(:friend) { double(first_name: "Selina", last_name: "Kyle") }
      let(:user) { double(first_name: "Bruce", last_name: "Wayne", friend: friend) }

      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :friend, serializer: self, hide: true
        end
      end

      let(:selection) { {with: "friend", except: "last_name,friend(first_name)"} }

      it "reads nested fields from parentheses" do
        expect(result).to eq({first_name: "Bruce", friend: {last_name: "Kyle"}})
      end
    end
  end

  describe "validating the field selection options" do
    subject(:serializer) { user_serializer.new(**options) }

    let!(:user_serializer) do
      check_selection = check_selection_config

      Class.new(Serega) do
        config.check_selection = check_selection

        attribute :name
      end
    end

    let(:check_selection_config) { true }
    let(:options) { {only: :name} }

    context "with a missing attribute in the field selection options" do
      let(:options) { {only: :email} }

      it "raises an AttributeNotExist error" do
        expect { serializer }.to raise_error Serega::AttributeNotExist
      end
    end

    context "with an unknown option" do
      let(:options) { {only: :name, foo: 1} }

      it "raises an ArgumentError that names the option" do
        expect { serializer }.to raise_error ArgumentError, /foo/
      end
    end

    context "when the config disables the validation" do
      let(:check_selection_config) { false }
      let(:options) { {only: :email} }

      it "builds an empty plan" do
        expect(serializer.plan.points).to be_empty
      end
    end

    context "when the check_selection option disables the validation" do
      let(:options) { {only: :email, check_selection: false} }

      it "builds an empty plan" do
        expect(serializer.plan.points).to be_empty
      end
    end
  end

  describe "field selection options of a relation" do
    subject(:result) { serializer.to_h(user, only: only, with: with, except: except) }

    let(:serializer) { user_serializer }

    let(:post_serializer) do
      Class.new(described_class) do
        attribute :id
        attribute :title
        attribute :body

        preset :summary, only: [:id, :title]
      end
    end

    let(:user_serializer) do
      posts = post_serializer

      Class.new(described_class) do
        attribute :name
        attribute :posts, serializer: posts, many: true, only: [:id, :title]
      end
    end

    let(:user) { Struct.new(:name, :posts).new("Ann", [post]) }
    let(:post) { Struct.new(:id, :title, :body).new(1, "Hello", "Text") }
    let(:only) { nil }
    let(:with) { nil }
    let(:except) { nil }

    it "serializes the fields of the options" do
      expect(result).to eq(name: "Ann", posts: [{id: 1, title: "Hello"}])
    end

    context "with with that names a nested field" do
      let(:with) { {posts: :body} }

      it "adds the field to the fields of the options" do
        expect(result).to eq(name: "Ann", posts: [{id: 1, title: "Hello", body: "Text"}])
      end
    end

    context "with except that names a nested field" do
      let(:except) { {posts: :title} }

      it "removes the field from the fields of the options" do
        expect(result).to eq(name: "Ann", posts: [{id: 1}])
      end
    end

    context "with a relation preset" do
      let(:serializer) do
        posts = post_serializer
        Class.new(described_class) { attribute :posts, serializer: posts, many: true, preset: :summary, with: :body }
      end

      it "merges the options into the preset" do
        expect(result).to eq(posts: [{id: 1, title: "Hello", body: "Text"}])
      end
    end

    context "with an unknown field of a serializer resolved later" do
      let(:serializer) do
        posts = post_serializer
        Class.new(described_class) { attribute :posts, serializer: -> { posts }, many: true, only: :subtitle }
      end

      it "raises AttributeNotExist" do
        expect { result }.to raise_error Serega::AttributeNotExist, "Relation :posts names not existing attributes: subtitle"
      end
    end
  end
end
