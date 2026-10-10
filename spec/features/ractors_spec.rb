# frozen_string_literal: true

require "support/ractors"

RSpec.describe Serega, if: defined?(Ractor) do
  let(:comment_class) { Struct.new(:text) }
  let(:post_class) { Struct.new(:id, :title, :comments) }
  let(:post) { post_class.new(1, "Hello", [comment_class.new("Nice")]) }

  let(:comment_serializer) do
    Class.new(described_class) do
      attribute :text, format: [:upcase]
      freeze
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
      freeze
    end
  end

  it "serializes in another Ractor" do
    result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, with: :comments, context: {multiplier: 10}) }

    expect(result).to eq(title: "Hello", rating: 10, headline: "Hello!", comments: [{text: "NICE"}])
  end

  it "serializes in another Ractor with the plan of the modifiers" do
    result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, only: {comments: :text}) }

    expect(result).to eq(comments: [{text: "NICE"}])
  end

  it "serializes to Data and Struct objects in another Ractor" do
    data = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_data(post, only: :title) }
    struct = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_struct(post, only: :title) }

    expect(data.to_h).to eq(title: "Hello")
    expect(struct.to_h).to eq(title: "Hello")
  end

  context "with a relation serializer given as a String" do
    let(:post_serializer) do
      stub_const("RactorCommentSerializer", comment_serializer)

      Class.new(described_class) do
        attribute :comments, serializer: "RactorCommentSerializer", many: true
        freeze
      end
    end

    it "finds the relation serializer in another Ractor" do
      result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) }

      expect(result).to eq(comments: [{text: "NICE"}])
    end
  end

  context "with a presenter method" do
    let(:number_serializer) do
      Class.new(described_class) do
        attribute :next_number

        presenter do
          def next_number = self + 1
        end

        freeze
      end
    end

    it "delegates to the wrapped object in another Ractor" do
      expect(run_in_ractor(number_serializer) { |serializer| serializer.to_h(1) }).to eq(next_number: 2)
    end
  end

  context "when the serializer is not frozen" do
    let(:post_serializer) { Class.new(described_class) { attribute :title } }

    it "raises an error in another Ractor" do
      expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
        .to raise_error Serega::SeregaError, "#{post_serializer} is not frozen. Call `freeze` at the end of its definition"
    end
  end

  context "with an attribute block that can not be shared" do
    let(:post_serializer) do
      suffix = +"!"

      Class.new(described_class) do
        attribute :title, value: proc { |post| post.title + suffix }
        freeze
      end
    end

    let(:location) { post_serializer.attributes[:title].location }

    it "serializes in the main Ractor" do
      expect(post_serializer.to_h(post)).to eq(title: "Hello!")
    end

    it "raises an error with the attribute location in another Ractor" do
      expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
        .to raise_error Serega::SeregaError, /\AAttribute :title of #{post_serializer} can not be shared between Ractors \(#{location}\): /
    end
  end
end
