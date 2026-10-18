# frozen_string_literal: true

require "support/ractors"

RSpec.describe Serega do
  let(:comment_class) { Struct.new(:text) }
  let(:post_class) { Struct.new(:id, :title, :comments) }
  let(:post) { post_class.new(1, "Hello", [comment_class.new("Nice")]) }

  let(:comment_serializer) do
    Class.new(described_class) do
      attribute :text, format: [:upcase]
      make_shareable!
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
      make_shareable!
    end
  end

  describe ".make_shareable!" do
    let(:post_serializer) { Class.new(described_class) { attribute :title } }

    it "returns the shareable serializer" do
      expect(post_serializer.make_shareable!).to be post_serializer
      expect(post_serializer).to be_shareable
    end

    context "when the serializer is shareable" do
      let(:post_serializer) { Class.new(described_class) { attribute :title }.make_shareable! }

      it "returns the serializer" do
        expect(post_serializer.make_shareable!).to be post_serializer
      end
    end

    context "with a nested serializer defined with a block" do
      let(:post_serializer) do
        Class.new(described_class) do
          config.base_serializer = Serega
          attribute(:comment) { attribute :text }
        end
      end

      it "makes the nested serializer shareable" do
        post_serializer.make_shareable!

        expect(post_serializer.attributes[:comment].serializer).to be_shareable
      end
    end
  end

  context "when the serializer is shareable" do
    it "serializes in the main Ractor" do
      expect(post_serializer.to_h(post, with: :comments, context: {multiplier: 10}))
        .to eq(title: "Hello", rating: 10, headline: "Hello!", comments: [{text: "NICE"}])
    end

    it "serializes to Data and Struct objects in the main Ractor" do
      expect(post_serializer.to_data(post, only: :title).to_h).to eq(title: "Hello")
      expect(post_serializer.to_struct(post, only: :title).to_h).to eq(title: "Hello")
    end

    it "raises an error on a definition change" do
      expect { post_serializer.attribute :id }
        .to raise_error Serega::SeregaError, "#{post_serializer} can not be changed after it was made shareable"
    end

    it "raises an error on a config change" do
      expect { post_serializer.config.max_cached_plans_per_serializer_count = 1 }.to raise_error FrozenError
    end
  end

  context "with a shareable relation serializer given as a String" do
    let(:post_serializer) do
      stub_const("RactorCommentSerializer", comment_serializer)

      Class.new(described_class) do
        attribute :comments, serializer: "RactorCommentSerializer", many: true
        make_shareable!
      end
    end

    it "finds the relation serializer in the main Ractor" do
      expect(post_serializer.to_h(post)).to eq(comments: [{text: "NICE"}])
    end

    it "finds the relation serializer in another Ractor", if: defined?(Ractor) do
      result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) }

      expect(result).to eq(comments: [{text: "NICE"}])
    end
  end

  describe "serialization in another Ractor", if: defined?(Ractor) do
    it "serializes the shareable serializer" do
      result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, with: :comments, context: {multiplier: 10}) }

      expect(result).to eq(title: "Hello", rating: 10, headline: "Hello!", comments: [{text: "NICE"}])
    end

    it "serializes with the plan of the modifiers" do
      result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, only: {comments: :text}) }

      expect(result).to eq(comments: [{text: "NICE"}])
    end

    it "serializes to Data and Struct objects" do
      data = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_data(post, only: :title) }
      struct = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_struct(post, only: :title) }

      expect(data.to_h).to eq(title: "Hello")
      expect(struct.to_h).to eq(title: "Hello")
    end

    context "with a nested serializer defined with a block" do
      let(:post_serializer) do
        Class.new(described_class) do
          config.base_serializer = Serega
          attribute(:comments, many: true) { attribute :text }
          make_shareable!
        end
      end

      it "serializes the nested serializer" do
        result = run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) }

        expect(result).to eq(comments: [{text: "Nice"}])
      end
    end

    context "with a presenter method" do
      let(:number_serializer) do
        Class.new(described_class) do
          attribute :next_number

          presenter do
            def next_number = self + 1
          end

          make_shareable!
        end
      end

      it "delegates to the wrapped object" do
        expect(run_in_ractor(number_serializer) { |serializer| serializer.to_h(1) }).to eq(next_number: 2)
      end
    end

    context "when the serializer is not shareable" do
      let(:post_serializer) { Class.new(described_class) { attribute :title } }

      it "raises an error" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
          .to raise_error Serega::SeregaError, "#{post_serializer} can not serialize in other Ractors. Call `make_shareable!` at the end of its definition"
      end
    end

    context "when the relation serializer is not shareable" do
      let(:comment_serializer) { Class.new(described_class) { attribute :text } }

      it "raises an error with the relation serializer name" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post, only: :comments) } }
          .to raise_error Serega::SeregaError, "#{comment_serializer} can not serialize in other Ractors. Call `make_shareable!` at the end of its definition"
      end
    end

    context "with an attribute block that can not be shared" do
      let(:post_serializer) do
        suffix = +"!"

        Class.new(described_class) do
          attribute :title, value: proc { |post| post.title + suffix }
          make_shareable!
        end
      end

      let(:location) { post_serializer.attributes[:title].location }

      it "serializes in the main Ractor" do
        expect(post_serializer.to_h(post)).to eq(title: "Hello!")
      end

      it "raises an error with the attribute location" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
          .to raise_error Serega::SeregaError, /\AAttribute :title of #{post_serializer} can not be shared between Ractors \(#{location}\): .*Proc.* variable .suffix'/
      end
    end

    context "with a batch loader that can not be shared" do
      let(:post_serializer) do
        ratings = {}

        Class.new(described_class) do
          batch(:ratings) { |_posts| ratings }
          make_shareable!
        end
      end

      it "raises an error with the batch loader name" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
          .to raise_error Serega::SeregaError, /\ABatch loader :ratings of #{post_serializer} can not be shared between Ractors: .*Proc.* variable .ratings'/
      end
    end

    context "with a formatter that can not be shared" do
      let(:post_serializer) do
        mark = +"!"

        Class.new(described_class) do
          formatter(:exclaim) { |title| "#{title}#{mark}" }
          make_shareable!
        end
      end

      it "raises an error with the formatter name" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
          .to raise_error Serega::SeregaError, /\AFormatter :exclaim of #{post_serializer} can not be shared between Ractors: .*Proc.* variable .mark'/
      end
    end

    context "with another definition that can not be shared" do
      let(:post_serializer) do
        preloaded = []

        Class.new(described_class) do
          preload_with { |posts, _preloads| preloaded.concat(posts) }
          make_shareable!
        end
      end

      it "raises an error with the serializer name" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
          .to raise_error Serega::SeregaError, /\A#{post_serializer} can not be shared between Ractors: .*Proc.* variable .preloaded'/
      end
    end

    context "with a constant value that can not be shared" do
      let(:post_serializer) do
        Class.new(described_class) do
          attribute :lock, const: Thread::Mutex.new
          make_shareable!
        end
      end

      let(:location) { post_serializer.attributes[:lock].location }

      it "serializes in the main Ractor" do
        expect(post_serializer.to_h(post)[:lock]).to be_a Thread::Mutex
      end

      it "raises an error" do
        expect { run_in_ractor(post_serializer, post) { |serializer, post| serializer.to_h(post) } }
          .to raise_error Serega::SeregaError, /\AAttribute :lock of #{post_serializer} can not be shared between Ractors \(#{location}\): .*Thread::Mutex/
      end
    end
  end
end
