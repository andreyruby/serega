# frozen_string_literal: true

require "support/ractors"

RSpec.describe Serega do
  let(:comment_class) { Struct.new(:text) }
  let(:post_class) { Struct.new(:id, :title, :comments) }
  let(:post) { post_class.new(1, "Hello", [comment_class.new("Nice")]) }

  let(:comment_serializer) do
    Class.new(described_class) do
      attribute :text, format: [:upcase]
    end
  end

  let(:post_serializer) do
    comments = comment_serializer

    Class.new(described_class) do
      batch(:ratings) { |posts, ctx:| posts.to_h { |post| [post.id, post.id * ctx[:multiplier]] } }

      attribute :title
      attribute :rating, batch: :ratings
      attribute :headline, value: proc { |post| "#{post.title}!" }, if: proc { |post| post.title }
      attribute :comments, serializer: comments, many: true, hide: true
    end
  end

  describe ".freeze" do
    it "returns the frozen serializer" do
      expect(post_serializer.freeze).to be post_serializer
      expect(post_serializer).to be_frozen
    end

    it "freezes the serializers of the relations", if: defined?(Ractor) do
      post_serializer.freeze

      expect(comment_serializer).to be_frozen
    end

    it "returns the frozen serializer when it is frozen" do
      post_serializer.freeze

      expect(post_serializer.freeze).to be post_serializer
    end

    it "keeps the subclasses unfrozen" do
      post_subclass = Class.new(post_serializer)
      post_serializer.freeze

      expect(post_subclass).not_to be_frozen
    end
  end

  context "when the serializer is frozen" do
    before { post_serializer.freeze }

    it "serializes in another Ractor", if: defined?(Ractor) do
      result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, with: :comments, context: {multiplier: 10}) }

      expect(result).to eq(title: "Hello", rating: 10, headline: "Hello!", comments: [{text: "NICE"}])
    end

    it "serializes in another Ractor with the plan of the modifiers", if: defined?(Ractor) do
      result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, only: {comments: :text}) }

      expect(result).to eq(comments: [{text: "NICE"}])
    end

    it "serializes to Data and Struct objects in another Ractor", if: defined?(Ractor) do
      data = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_data(post, only: :title) }
      struct = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_struct(post, only: :title) }

      expect(data.to_h).to eq(title: "Hello")
      expect(struct.to_h).to eq(title: "Hello")
    end

    it "serializes in the main Ractor" do
      expect(post_serializer.to_h(post, only: :title)).to eq(title: "Hello")
    end
  end

  context "when the serializer is not frozen" do
    it "raises an error in another Ractor", if: defined?(Ractor) do
      expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
        .to raise_error Serega::SeregaError,
          "#{post_serializer} can not serialize in a non-main Ractor until `#{post_serializer}.freeze` is called in the main Ractor"
    end
  end

  context "with presenter methods" do
    let(:number_serializer) do
      Class.new(described_class) do
        attribute :next_number

        presenter do
          def next_number = self + 1
        end
      end
    end

    before { number_serializer.freeze }

    it "delegates to the wrapped object in another Ractor", if: defined?(Ractor) do
      expect(run_in_ractor(number_serializer) { |serializer| serializer.to_h(1) }).to eq(next_number: 2)
    end
  end
end
