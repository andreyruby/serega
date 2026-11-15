# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptPreset do
  subject(:check) { described_class.call(opts, block) }

  let(:post_serializer) do
    Class.new(Serega) do
      attribute :title
      preset :summary, only: :title
    end
  end

  let(:serializer) { post_serializer }
  let(:preset) { [:summary, "summary"] }
  let(:opts) { {serializer: serializer, preset: preset} }
  let(:block) { nil }

  it "accepts the presets of the relation serializer" do
    expect { check }.not_to raise_error
  end

  context "without the :preset option" do
    let(:opts) { {} }

    it "accepts the options" do
      expect { check }.not_to raise_error
    end
  end

  context "without a relation" do
    let(:opts) { {preset: preset} }

    it "raises a SeregaError" do
      expect { check }
        .to raise_error Serega::SeregaError, "Option :preset can be provided only together with :serializer option or a block"
    end
  end

  context "with a block" do
    let(:opts) { {preset: :summary} }
    let(:block) { proc {} }

    it "accepts the option" do
      expect { check }.not_to raise_error
    end
  end

  context "with an invalid value" do
    let(:preset) { 1 }

    it "raises a SeregaError" do
      expect { check }
        .to raise_error Serega::SeregaError, "Invalid option :preset => 1. Must be a Symbol, a String, or an Array of them"
    end
  end

  context "with an undefined preset" do
    let(:preset) { :full }

    it "raises PresetNotExist" do
      expect { check }.to raise_error Serega::PresetNotExist, "Preset :full is not defined in #{post_serializer}"
    end
  end

  context "with an undefined preset of a serializer given as a String" do
    let(:serializer) { "PostSerializer" }
    let(:preset) { :full }

    it "accepts the option" do
      expect { check }.not_to raise_error
    end
  end
end
