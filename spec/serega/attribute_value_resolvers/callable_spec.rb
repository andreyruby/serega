# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers::Callable do
  let(:resolver) { described_class.new(callable) }
  let(:callable) { proc { |user| user } }

  describe "#callable" do
    it "returns the callable" do
      expect(resolver.callable).to equal callable
    end
  end

  describe "#call" do
    subject(:value) { resolver.call(:user, ctx: :context, batches: :batches) }

    it "calls the callable with the object" do
      expect(value).to eq :user
    end

    context "with a callable without parameters" do
      let(:callable) { proc { :none } }

      it "calls the callable without arguments" do
        expect(value).to eq :none
      end
    end

    context "with a callable with the context parameter" do
      let(:callable) { proc { |user, ctx| [user, ctx] } }

      it "calls the callable with the object and the context" do
        expect(value).to eq %i[user context]
      end
    end

    context "with a callable with the :ctx keyword" do
      let(:callable) { proc { |user, ctx:| [user, ctx] } }

      it "calls the callable with the :ctx keyword" do
        expect(value).to eq %i[user context]
      end
    end

    context "with a callable with the :batches keyword" do
      let(:callable) { proc { |user, batches:| [user, batches] } }

      it "calls the callable with the :batches keyword" do
        expect(value).to eq %i[user batches]
      end
    end

    context "with a callable with the :ctx and :batches keywords" do
      let(:callable) { proc { |user, ctx:, batches:| [user, ctx, batches] } }

      it "calls the callable with the :ctx and :batches keywords" do
        expect(value).to eq %i[user context batches]
      end
    end

    context "with a callable with the context parameter and the :ctx and :batches keywords" do
      let(:callable) { lambda { |user, context, ctx:, batches:| [user, context, ctx, batches] } }

      it "calls the callable with the context and the :ctx and :batches keywords" do
        expect(value).to eq %i[user context context batches]
      end
    end
  end

  describe "#code" do
    subject(:code) { resolver.code("source", "callable", "batches") }

    it "returns the code that calls the callable with the source" do
      expect(code).to eq "callable.call(source)"
    end

    context "with a callable without parameters" do
      let(:callable) { proc { :none } }

      it "returns the code that calls the callable without arguments" do
        expect(code).to eq "callable.call"
      end
    end

    context "with a callable with the context parameter" do
      let(:callable) { proc { |user, ctx| [user, ctx] } }

      it "returns the code that calls the callable with the source and the context" do
        expect(code).to eq "callable.call(source, context)"
      end
    end

    context "with a callable with the :ctx keyword" do
      let(:callable) { proc { |user, ctx:| [user, ctx] } }

      it "returns the code that calls the callable with the :ctx keyword" do
        expect(code).to eq "callable.call(source, ctx: context)"
      end
    end

    context "with a callable with the :batches keyword" do
      let(:callable) { proc { |user, batches:| [user, batches] } }

      it "returns the code that calls the callable with the :batches keyword" do
        expect(code).to eq "callable.call(source, batches: batches)"
      end
    end

    context "with a callable with the :ctx and :batches keywords" do
      let(:callable) { proc { |user, ctx:, batches:| [user, ctx, batches] } }

      it "returns the code that calls the callable with the :ctx and :batches keywords" do
        expect(code).to eq "callable.call(source, ctx: context, batches: batches)"
      end
    end

    context "with a callable with the context parameter and the :ctx and :batches keywords" do
      let(:callable) { lambda { |user, context, ctx:, batches:| [user, context, ctx, batches] } }

      it "returns the code that calls the callable with the context and the :ctx and :batches keywords" do
        expect(code).to eq "callable.call(source, context, ctx: context, batches: batches)"
      end
    end
  end
end
