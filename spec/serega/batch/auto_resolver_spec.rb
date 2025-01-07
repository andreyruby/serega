# frozen_string_literal: true

RSpec.describe Serega::SeregaBatch::AutoResolver do
  let(:loader_name) { :user }
  let(:id_method) { :id }

  describe "#initialize" do
    subject(:resolver) { described_class.new(loader_name, id_method) }

    it "sets loader_name and id_method" do
      expect(resolver.loader_name).to eq(:user)
      expect(resolver.id_method).to eq(:id)
    end
  end

  describe "#call" do
    let(:obj) { double(id: 1) }
    let(:batch_values) { {1 => "John"} }
    let(:batches) { {user: batch_values} }
    let(:resolver) { described_class.new(loader_name, id_method) }

    it "fetches value from batch hash using object's id" do
      expect(resolver.call(obj, batches: batches)).to eq("John")
    end

    context "when using custom id method" do
      let(:id_method) { :user_id }
      let(:obj) { double(user_id: 2) }
      let(:batch_values) { {2 => "Jane"} }

      it "fetches value using custom id method" do
        expect(resolver.call(obj, batches: batches)).to eq("Jane")
      end
    end

    context "when batch hash is empty" do
      let(:batch_values) { {} }

      it "raises KeyError" do
        expect(resolver.call(obj, batches: batches)).to be_nil
      end
    end

    context "when batch hash doesn't contain loader_name" do
      let(:batches) { {} }

      it "raises KeyError" do
        expect { resolver.call(obj, batches: batches) }.to raise_error(KeyError)
      end
    end
  end
end
