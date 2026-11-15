# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::Presets do
  let!(:user_serializer) do
    Class.new(Serega) do
      attribute :name
      attribute :email, hide: true

      preset :contacts, with: :email
      preset :profile, preset: :contacts, only: :name
    end
  end

  let(:check_preset_params) { instance_double(Serega::SeregaValidations::CheckPresetParams) }

  before do
    allow(Serega::SeregaValidations::CheckPresetParams).to receive(:new).and_return(check_preset_params)
    allow(check_preset_params).to receive(:validate)
  end

  describe ".define" do
    subject(:definition) { described_class.define(user_serializer, "card", ["contacts"], "name", nil, nil) }

    it "returns the frozen names of the included presets and the own parsed selection" do
      expect(definition).to eq(presets: [:contacts], only: {name: {}}, with: {}, except: {})
      expect(definition).to be_frozen
      expect(definition[:presets]).to be_frozen
      expect(definition[:only][:name]).to be_frozen

      expect(Serega::SeregaValidations::CheckPresetParams).to have_received(:new)
        .with(user_serializer, "card", ["contacts"], "name", nil, nil)
      expect(check_preset_params).to have_received(:validate)
    end
  end

  describe ".definition" do
    subject(:definition) { described_class.definition(preset, nil, "email", nil) }

    let(:preset) { "contacts" }

    it "returns the frozen preset names and the parsed selection" do
      expect(definition).to eq(presets: [:contacts], only: {}, with: {email: {}}, except: {})
      expect(definition).to be_frozen
    end

    context "without presets" do
      let(:preset) { nil }

      it "returns no preset names" do
        expect(definition[:presets]).to equal Serega::FROZEN_EMPTY_ARRAY
      end
    end
  end

  describe ".selection" do
    subject(:merged) { described_class.selection(user_serializer, preset, selection) }

    let(:preset) { ["profile"] }
    let(:selection) { {only: {}, with: {}, except: {email: {}}} }

    it "merges the given selection into the selection of the presets" do
      expect(merged).to eq(only: {name: {}}, with: {email: {}}, except: {email: {}})
      expect(Serega::SeregaValidations::CheckPresetParams).not_to have_received(:new)
    end

    it "leaves the serializer unlocked" do
      merged

      expect { user_serializer.attribute :phone }.not_to raise_error
    end

    context "with an undefined preset" do
      let(:preset) { :admin }

      it "raises a PresetNotExist error" do
        expect { merged }.to raise_error(Serega::PresetNotExist, "Preset :admin is not defined in #{user_serializer}")
      end
    end

    context "with a preset of another type" do
      let(:preset) { {contacts: true} }

      it "raises a SeregaError" do
        expect { merged }
          .to raise_error Serega::SeregaError, "Invalid option :preset => #{preset.inspect}. Must be a Symbol, a String, or an Array of them"
      end
    end

    context "with an Array of preset names of another type" do
      let(:preset) { [:contacts, 1] }

      it "raises a SeregaError" do
        expect { merged }
          .to raise_error Serega::SeregaError, "Invalid option :preset => [:contacts, 1]. Must be a Symbol, a String, or an Array of them"
      end
    end
  end

  describe ".relation_selection" do
    subject(:merged) { described_class.relation_selection(attribute, selection) }

    let(:attribute) { post_serializer.attributes[:author] }
    let(:selection) { {only: nil, with: nil, except: {email: {}}} }

    let(:post_serializer) do
      users = user_serializer
      Class.new(Serega) { attribute :author, serializer: users, preset: :contacts, only: :name }
    end

    before { allow(Serega::SeregaValidations::CheckRelationSelection).to receive(:call) }

    it "merges the definition of the relation and the given selection into the selection of the presets" do
      expect(merged).to eq(only: {name: {}}, with: {email: {}}, except: {email: {}})
      expect(Serega::SeregaValidations::CheckRelationSelection).to have_received(:call).with(attribute, user_serializer)
    end
  end
end
