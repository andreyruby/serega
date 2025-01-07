# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckBatchLoaderParams do
  subject(:validate) { described_class.new(name, batch_loader).validate }

  let(:name) { :test_loader }
  let(:batch_loader) { proc { |objects| {} } }

  describe "#validate" do
    context "with valid parameters" do
      it "does not raise error with symbol name and proc loader" do
        expect { validate }.not_to raise_error
      end

      context "with string name" do
        let(:name) { "test_loader" }

        it "does not raise error" do
          expect { validate }.not_to raise_error
        end
      end

      context "with callable object" do
        let(:batch_loader) do
          Class.new do
            def self.call(objects)
            end
          end
        end

        it "does not raise error" do
          expect { validate }.not_to raise_error
        end
      end
    end

    context "with invalid name" do
      context "when name is not symbol or string" do
        let(:name) { 123 }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, "Batch loader name must be a Symbol or String")
        end
      end

      context "when name is nil" do
        let(:name) { nil }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, "Batch loader name must be a Symbol or String")
        end
      end

      context "when name is array" do
        let(:name) { [:test] }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, "Batch loader name must be a Symbol or String")
        end
      end
    end

    context "with invalid batch_loader type" do
      context "when batch_loader is not proc or callable" do
        let(:batch_loader) { "not callable" }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, "Batch loader value must be a Proc or respond to #call")
        end
      end

      context "when batch_loader is nil" do
        let(:batch_loader) { nil }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, "Batch loader value must be a Proc or respond to #call")
        end
      end

      context "when batch_loader is number" do
        let(:batch_loader) { 123 }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, "Batch loader value must be a Proc or respond to #call")
        end
      end
    end

    context "with invalid batch_loader arguments" do
      let(:expected_error_message) do
        <<~ERR.strip
          Batch loader arguments should have one of this signatures:
          - (objects)       # one argument
          - (objects, :ctx) # one argument and one :ctx keyword argument
        ERR
      end

      context "when batch_loader has no arguments" do
        let(:batch_loader) { proc {} }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, expected_error_message)
        end
      end

      context "when batch_loader has too many positional arguments" do
        let(:batch_loader) { lambda { |objects, context, extra| {} } }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, expected_error_message)
        end
      end

      context "when batch_loader has wrong keyword arguments" do
        let(:batch_loader) { proc { |objects, wrong:| {} } }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, expected_error_message)
        end
      end

      context "when batch_loader has multiple keyword arguments" do
        let(:batch_loader) { proc { |objects, ctx:, extra:| {} } }

        it "raises error" do
          expect { validate }.to raise_error(Serega::SeregaError, expected_error_message)
        end
      end
    end

    context "with valid batch_loader arguments" do
      context "with one positional argument" do
        let(:batch_loader) { proc { |objects| {} } }

        it "allows" do
          expect { validate }.not_to raise_error
        end
      end

      context "with one positional argument and ctx keyword argument" do
        let(:batch_loader) { proc { |objects, ctx:| {} } }

        it "allows" do
          expect { validate }.not_to raise_error
        end
      end

      context "with lambda with one argument" do
        let(:batch_loader) { lambda { |objects| {} } }

        it "allows" do
          expect { validate }.not_to raise_error
        end
      end

      context "with lambda with one argument and ctx keyword" do
        let(:batch_loader) { lambda { |objects, ctx:| {} } }

        it "allows" do
          expect { validate }.not_to raise_error
        end
      end

      context "with callable class with one argument" do
        let(:batch_loader) do
          Class.new do
            def self.call(objects)
            end
          end
        end

        it "allows" do
          expect { validate }.not_to raise_error
        end
      end

      context "with callable class with one argument and ctx keyword" do
        let(:batch_loader) do
          Class.new do
            def self.call(objects, ctx:)
            end
          end
        end

        it "allows" do
          expect { validate }.not_to raise_error
        end
      end
    end
  end

  describe "instance attributes" do
    let(:validator) { described_class.new(name, batch_loader) }

    it "exposes name attribute" do
      expect(validator.name).to eq(name)
    end

    it "exposes batch_loader attribute" do
      expect(validator.batch_loader).to eq(batch_loader)
    end
  end
end
