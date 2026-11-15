# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckPresetParams do
  subject(:validate) { described_class.new(user_serializer, name, preset, only, nil, nil).validate }

  let(:user_serializer) do
    Class.new(Serega) do
      attribute :name
      attribute :email, hide: true

      preset :contacts, with: :email
    end
  end

  let(:name) { :card }
  let(:preset) { :contacts }
  let(:only) { {name: true} }

  it "accepts valid parameters" do
    expect { validate }.not_to raise_error
  end

  context "with a String name and String preset names" do
    let(:name) { "card" }
    let(:preset) { ["contacts"] }

    it "accepts the parameters" do
      expect { validate }.not_to raise_error
    end
  end

  context "with an invalid name" do
    let(:name) { 1 }

    it "raises a SeregaError" do
      expect { validate }.to raise_error Serega::SeregaError, "Preset name must be a Symbol or a String, 1 provided"
    end
  end

  context "with a preset of another type" do
    let(:preset) { {contacts: true} }

    it "raises a SeregaError" do
      expect { validate }
        .to raise_error Serega::SeregaError, "Invalid option :preset => #{preset.inspect}. Must be a Symbol, a String, or an Array of them"
    end
  end

  context "with an Array of preset names of another type" do
    let(:preset) { [:contacts, 1] }

    it "raises a SeregaError" do
      expect { validate }
        .to raise_error Serega::SeregaError, "Invalid option :preset => [:contacts, 1]. Must be a Symbol, a String, or an Array of them"
    end
  end

  context "with an undefined preset" do
    let(:preset) { :admin }

    it "raises a PresetNotExist error" do
      expect { validate }.to raise_error(Serega::PresetNotExist, "Preset :admin is not defined in #{user_serializer}") do |error|
        expect(error.serializer).to eq user_serializer
        expect(error.preset).to eq :admin
      end
    end
  end

  context "with the name of an included preset" do
    let(:name) { :contacts }

    it "raises a SeregaError" do
      expect { validate }
        .to raise_error Serega::SeregaError, "Presets of #{user_serializer} include each other: contacts -> contacts"
    end
  end

  context "with the name of a preset that includes the included preset" do
    let(:name) { :contacts }
    let(:preset) { :profile }

    before { user_serializer.preset :profile, preset: :contacts }

    it "raises a SeregaError" do
      expect { validate }
        .to raise_error Serega::SeregaError, "Presets of #{user_serializer} include each other: contacts -> profile -> contacts"
    end
  end

  context "with included presets that include the same preset" do
    let(:preset) { %i[names emails] }

    before do
      user_serializer.preset :names, preset: :contacts, only: :name
      user_serializer.preset :emails, preset: :contacts
    end

    it "accepts the parameters" do
      expect { validate }.not_to raise_error
    end
  end

  context "with invalid selection" do
    let(:only) { [:name, 1] }

    it "raises a SeregaError" do
      expect { validate }.to raise_error Serega::SeregaError,
        "Invalid :only => [:name, 1] in preset :card. Must be a Symbol, a String, an Array or a Hash of attribute names"
    end
  end

  context "without selection" do
    let(:preset) { nil }
    let(:only) { nil }

    it "raises a SeregaError" do
      expect { validate }
        .to raise_error Serega::SeregaError, "Preset :card must select fields with :only, :with, :except or :preset"
    end
  end

  context "with nested fields" do
    let!(:user_serializer) { super() }
    let(:preset) { nil }
    let(:check_selection) { instance_double(Serega::SeregaValidations::CheckPresetSelection) }
    let(:only) { "posts(title)" }

    before do
      allow(Serega::SeregaValidations::CheckPresetSelection).to receive(:new).and_return(check_selection)
      allow(check_selection).to receive(:call)
    end

    it "checks the parsed fields without resolving the relation serializers" do
      validate

      expect(Serega::SeregaValidations::CheckPresetSelection).to have_received(:new)
      expect(check_selection).to have_received(:call).with(user_serializer, {posts: {title: {}}}, {}, {})
    end
  end

  context "with attributes that do not exist" do
    let(:only) { [:nickname, {age: :years}] }

    it "raises an AttributeNotExist error for the first level names" do
      expect { validate }.to raise_error(Serega::AttributeNotExist, "Preset :card names not existing attributes: nickname, age") do |error|
        expect(error.serializer).to eq user_serializer
        expect(error.attributes).to eq %w[nickname age]
      end
    end
  end
end
