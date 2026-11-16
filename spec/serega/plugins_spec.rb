# frozen_string_literal: true

RSpec.describe Serega::SeregaPlugins do
  describe ".find" do
    subject(:find) { described_class.find(name) }

    let(:name) { :root }

    it "returns the plugin module" do
      expect(find).to be Serega::SeregaPlugins::Root
    end

    context "with an unknown name" do
      let(:name) { :foo }

      it "raises an error" do
        expect { find }.to raise_error Serega::SeregaError, "Plugin :foo does not exist"
      end
    end
  end

  describe ".deprecation_warning" do
    subject(:warning) { described_class.deprecation_warning(serializer_class, name) }

    let(:serializer_class) { Class.new(Serega) }
    let(:name) { :root }

    it "names the serializer, the plugin and its replacement" do
      expect(warning).to eq "#{serializer_class}: plugin :root is deprecated. Migrate to a response serializer with " \
        "data and meta attributes: " \
        "https://github.com/andreyruby/serega/blob/master/docs/migrating-from-root-and-metadata.md. " \
        "Set config.deprecation_warnings = false to hide this warning."
    end

    context "with the metadata plugin" do
      let(:name) { :metadata }

      it "returns a warning" do
        expect(warning).to include "plugin :metadata is deprecated"
      end
    end

    context "with the context_metadata plugin" do
      let(:name) { :context_metadata }

      it "returns a warning" do
        expect(warning).to include "plugin :context_metadata is deprecated"
      end
    end

    context "with a plugin that is not deprecated" do
      let(:name) { :activerecord_preloads }

      it "returns nil" do
        expect(warning).to be_nil
      end
    end
  end

  describe "Serega.plugin" do
    subject(:load_plugin) { serializer_class.plugin(:root, root: :user) }

    let(:deprecation_warnings) { false }

    let(:serializer_class) do
      warnings = deprecation_warnings
      Class.new(Serega) { config.deprecation_warnings = warnings }
    end

    before do
      allow(Serega::SeregaPlugins::Root).to receive(:apply)
      allow(serializer_class).to receive(:warn)
    end

    it "loads the plugin with its options and returns the plugin module" do
      expect(load_plugin).to be Serega::SeregaPlugins::Root

      expect(Serega::SeregaPlugins::Root).to have_received(:apply).with(serializer_class, root: :user)
      expect(serializer_class).not_to have_received(:warn)
    end

    context "when deprecation warnings are on" do
      let(:deprecation_warnings) { true }

      it "warns about the deprecated plugin at the line that loads it" do
        load_plugin

        warning = described_class.deprecation_warning(serializer_class, :root)
        expect(serializer_class).to have_received(:warn).with(warning, uplevel: 1)
      end
    end

    it "marks the plugin as used" do
      expect { load_plugin }.to change { serializer_class.plugin_used?(:root) }.from(false).to(true)
    end

    context "when the plugin is already loaded" do
      let(:serializer_class) { Class.new(Serega) { plugin :root } }

      it "raises an error" do
        expect { load_plugin }.to raise_error Serega::SeregaError, "This plugin is already loaded"
      end
    end
  end
end
