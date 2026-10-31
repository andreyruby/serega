# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode::AttributePointCode do
  let(:point_code) { described_class.new(point, 1) }
  let(:point) { default_plan(serializer).points.first }
  let(:serializer) { Class.new(Serega) { attribute :name } }

  describe "#variables" do
    subject(:variables) { point_code.variables }

    it "returns no variables" do
      expect(variables).to eq []
    end

    context "with a :value attribute" do
      let(:serializer) { Class.new(Serega) { attribute :name, value: proc { |user| user.name } } }

      it "returns the code that reads the attribute" do
        expect(variables).to eq ["attribute_1 = @points[1].attribute"]
      end
    end

    context "with a batch attribute and a condition" do
      let(:serializer) do
        Class.new(Serega) do
          batch :ratings, proc { |users| users.to_h { |user| [user.id, 5] } }
          attribute :rating, batch: :ratings, if: :active?
        end
      end

      it "returns the code that reads the attribute, the batches and the conditions" do
        expect(variables).to eq [
          "attribute_1 = @points[1].attribute",
          "batches_1 = batches[1]",
          "conditions_1 = @points[1].attribute.conditions"
        ]
      end
    end
  end

  describe "#assign_value" do
    subject(:code) { point_code.assign_value }

    it "returns the code that reads the value with a rescue" do
      expect(code).to eq <<~RUBY.chomp
        value_1 =
          begin
            source.name
          rescue => error
            Serega::SeregaUtils::SerializedAttributeError.call(error, @points[1])
          end
      RUBY
    end

    context "with a :value attribute" do
      let(:serializer) { Class.new(Serega) { attribute :name, value: proc { |user| user.name } } }

      it "returns the code that calls the attribute" do
        expect(code).to include "attribute_1.value(source, context)"
      end
    end

    context "with a batch attribute" do
      let(:serializer) do
        Class.new(Serega) do
          batch :ratings, proc { |users| users.to_h { |user| [user.id, 5] } }
          attribute :rating, batch: :ratings
        end
      end

      it "returns the code that calls the attribute with the batches" do
        expect(code).to include "attribute_1.value(source, context, batches: batches_1)"
      end
    end

    context "with a conditional attribute" do
      let(:serializer) { Class.new(Serega) { attribute :name, if: :active? } }

      it "returns the code that gives SKIP when the conditions fail" do
        expect(code).to eq <<~RUBY.chomp
          value_1 =
            if conditions_1.satisfy?(source, context)
              value_1 =
                begin
                  source.name
                rescue => error
                  Serega::SeregaUtils::SerializedAttributeError.call(error, @points[1])
                end
              conditions_1.satisfy_value?(value_1, context) ? value_1 : Serega::SeregaEngine::SKIP
            else
              Serega::SeregaEngine::SKIP
            end
        RUBY
      end
    end
  end

  describe "#call_one?" do
    subject(:call_one) { point_code.call_one? }

    it "returns true" do
      expect(call_one).to be true
    end

    context "with a batch attribute" do
      let(:serializer) do
        Class.new(Serega) do
          batch :ratings, proc { |users| users.to_h { |user| [user.id, 5] } }
          attribute :rating, batch: :ratings
        end
      end

      it "returns false" do
        expect(call_one).to be false
      end
    end
  end
end
