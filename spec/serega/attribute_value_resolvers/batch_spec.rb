# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers do
  describe described_class::BatchResolver do
    let(:serializer_class) { Class.new(Serega) }
    let(:attribute_name) { :user }
    let(:batch_id_option) { :some_id }

    before do
      serializer_class.config.batch_id_option = batch_id_option
    end

    describe ".get" do
      subject(:resolver) { described_class.get(serializer_class, attribute_name, batch_opt) }

      context "when batch_opt is true" do
        let(:batch_opt) { true }

        it "creates resolver with attribute name and :id method" do
          expect(resolver.instance_variable_get(:@loader_name)).to eq(:user)
          expect(resolver.instance_variable_get(:@id_method)).to eq(batch_id_option)
        end
      end

      context "when batch_opt is a callable" do
        let(:batch_opt) { proc { |objects| objects.map(&:id) } }

        it "creates resolver with attribute name and :id method" do
          allow(serializer_class).to receive(:batch)
          resolver
          expect(serializer_class).to have_received(:batch).with(:user, batch_opt)
          expect(resolver.instance_variable_get(:@loader_name)).to eq(:user)
          expect(resolver.instance_variable_get(:@id_method)).to eq(batch_id_option)
        end
      end

      context "when batch_opt is a hash with callable use" do
        let(:batch_opt) { {use: proc { |objects| objects.map(&:id) }} }

        it "creates resolver with attribute name and :id method" do
          allow(serializer_class).to receive(:batch)
          resolver
          expect(serializer_class).to have_received(:batch).with(:user, batch_opt[:use])
          expect(resolver.instance_variable_get(:@loader_name)).to eq(:user)
          expect(resolver.instance_variable_get(:@id_method)).to eq(batch_id_option)
        end
      end

      context "when batch_opt is a hash with symbol use" do
        let(:batch_opt) { {use: :custom_loader} }

        it "creates resolver with custom loader name and :id method" do
          expect(resolver.instance_variable_get(:@loader_name)).to eq(:custom_loader)
          expect(resolver.instance_variable_get(:@id_method)).to eq(batch_id_option)
        end
      end

      context "when batch_opt is a hash with custom id method" do
        let(:batch_opt) { {use: :custom_loader, id: :custom_id} }

        it "creates resolver with custom loader name and custom id method" do
          expect(resolver.instance_variable_get(:@loader_name)).to eq(:custom_loader)
          expect(resolver.instance_variable_get(:@id_method)).to eq(:custom_id)
        end
      end
    end
  end

  describe described_class::Batch do
    let(:loader_name) { :user }
    let(:id_method) { :id }

    describe "#initialize" do
      subject(:resolver) { described_class.new(loader_name, id_method) }

      it "sets loader_name and id_method" do
        expect(resolver.instance_variable_get(:@loader_name)).to eq(:user)
        expect(resolver.instance_variable_get(:@id_method)).to eq(:id)
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
end
