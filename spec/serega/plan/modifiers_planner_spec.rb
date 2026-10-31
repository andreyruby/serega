# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::ModifiersPlanner do
  let(:user_serializer) do
    Class.new(Serega) do
      attribute :name
      attribute :email, hide: true
    end
  end

  describe ".parse" do
    subject(:modifiers) { described_class.parse(only, with, except) }

    let(:only) { "name,posts(title)" }
    let(:with) { [:email] }
    let(:except) { nil }

    it "returns the modifiers as Hashes of attribute names" do
      expect(modifiers).to eq(only: {name: {}, posts: {title: {}}}, with: {email: {}}, except: {})
    end

    context "without modifiers" do
      subject(:modifiers) { described_class.parse }

      it "returns empty Hashes" do
        expect(modifiers).to eq(only: {}, with: {}, except: {})
      end
    end
  end

  describe ".empty?" do
    subject(:empty) { described_class.empty?(modifiers) }

    let(:modifiers) { {only: {}, with: {}, except: {}} }

    it "returns true" do
      expect(empty).to be true
    end

    context "when a modifier names an attribute" do
      let(:modifiers) { {only: {}, with: {email: {}}, except: {}} }

      it "returns false" do
        expect(empty).to be false
      end
    end
  end

  describe ".validate" do
    let(:check_modifiers) { instance_double(Serega::SeregaValidations::Initiate::CheckModifiers) }
    let(:modifiers) { {only: {name: {}}, with: {email: {}}, except: {}} }

    before do
      allow(Serega::SeregaValidations::Initiate::CheckModifiers).to receive(:new).and_return(check_modifiers)
      allow(check_modifiers).to receive(:call)
    end

    it "checks the modifiers of the serializer" do
      described_class.validate(user_serializer, modifiers)

      expect(Serega::SeregaValidations::Initiate::CheckModifiers).to have_received(:new)
      expect(check_modifiers).to have_received(:call).with(user_serializer, {name: {}}, {email: {}}, {})
    end
  end

  describe ".plan" do
    subject(:plan) { described_class.plan(user_serializer, modifiers) }

    let(:modifiers) { {only: {}, with: {email: {}}, except: {}} }

    it "returns the plan of the selected attributes" do
      expect(plan.points.map(&:name)).to eq [:name, :email]
    end
  end
end
