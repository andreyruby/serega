# frozen_string_literal: true

RSpec.describe Serega do
  describe "serialization" do
    subject(:result) { user_serializer.new(**modifiers).to_h(user, context: context) }

    let(:context) { {} }
    let(:modifiers) { {} }

    context "with object with Struct relation" do
      let(:statistics_struct) { Struct.new(:likes_count, :comments_count) }

      let(:statistics_serializer) do
        Class.new(Serega) do
          attribute :likes_count
          attribute :comments_count
          freeze
        end
      end

      let(:user) { double(statistics: statistics_struct.new(10, 20)) }

      let(:user_serializer) do
        child_serializer = statistics_serializer
        Class.new(Serega) do
          attribute :statistics, serializer: child_serializer
          freeze
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
          freeze
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }

      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
          freeze
        end
      end

      it "returns hash with relations" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT"}})
      end

      context "with `many: false`" do
        let(:user_serializer) do
          child_serializer = comment_serializer
          Class.new(Serega) do
            attribute :first_name
            attribute :last_name
            attribute :comment, serializer: child_serializer, many: false
            freeze
          end
        end

        it "returns hash with relations" do
          expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT"}})
        end
      end
    end

    context "with object with array relation" do
      let(:comments) { [double(text: "TEXT")] }

      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
          freeze
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: comments) }

      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comments, serializer: child_serializer
          freeze
        end
      end

      it "returns hash with relations" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: [{text: "TEXT"}]})
      end

      context "with `many: true`" do
        let(:user_serializer) do
          child_serializer = comment_serializer
          Class.new(Serega) do
            attribute :first_name
            attribute :last_name
            attribute :comments, serializer: child_serializer, many: true
            freeze
          end
        end

        it "returns hash with relations" do
          expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: [{text: "TEXT"}]})
        end
      end
    end
  end
end
