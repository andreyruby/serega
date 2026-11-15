# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::SelectionPlanner do
  let(:user_serializer) do
    Class.new(Serega) do
      attribute :name
      attribute :email, hide: true
    end
  end

  describe ".parse" do
    subject(:selection) { described_class.parse(user_serializer, only, with, except, preset) }

    let(:only) { "name,posts(title)" }
    let(:with) { [:email] }
    let(:except) { nil }
    let(:preset) { nil }

    it "returns the selection as Hashes of attribute names" do
      expect(selection).to eq(only: {name: {}, posts: {title: {}}}, with: {email: {}}, except: {})
    end

    context "without field selection options" do
      subject(:selection) { described_class.parse(user_serializer) }

      it "returns empty Hashes" do
        expect(selection).to eq(only: {}, with: {}, except: {})
      end
    end

    context "with a preset" do
      let(:preset) { :contacts }
      let(:presets_selection) { {only: {name: {}}, with: {email: {}}, except: {}} }

      before { allow(Serega::SeregaPlan::Presets).to receive(:selection).and_return(presets_selection) }

      it "returns the selection merged with the selection of the presets" do
        expect(selection).to equal presets_selection
        expect(Serega::SeregaPlan::Presets).to have_received(:selection)
          .with(user_serializer, :contacts, {only: {name: {}, posts: {title: {}}}, with: {email: {}}, except: {}})
      end
    end
  end

  describe ".empty?" do
    subject(:empty) { described_class.empty?(selection) }

    let(:selection) { {only: {}, with: {}, except: {}} }

    it "returns true" do
      expect(empty).to be true
    end

    context "when a option names an attribute" do
      let(:selection) { {only: {}, with: {email: {}}, except: {}} }

      it "returns false" do
        expect(empty).to be false
      end
    end
  end

  describe ".validate" do
    let(:check_selection) { instance_double(Serega::SeregaValidations::CheckSelection) }
    let(:selection) { {only: {name: {}}, with: {email: {}}, except: {}} }

    before do
      allow(Serega::SeregaValidations::CheckSelection).to receive(:new).and_return(check_selection)
      allow(check_selection).to receive(:call)
    end

    it "checks the selection of the serializer" do
      described_class.validate(user_serializer, selection)

      expect(Serega::SeregaValidations::CheckSelection).to have_received(:new)
      expect(check_selection).to have_received(:call).with(user_serializer, {name: {}}, {email: {}}, {})
    end
  end

  describe ".plan" do
    subject(:plan) { described_class.plan(user_serializer, selection) }

    let(:selection) { {only: {}, with: {email: {}}, except: {}} }

    it "returns the plan of the selected attributes" do
      expect(plan.points.map(&:name)).to eq [:name, :email]
    end
  end
end
