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

  describe "Serega.plugin" do
    subject(:load_plugin) { serializer_class.plugin(:root, root: :user) }

    let(:serializer_class) { Class.new(Serega) }

    before do
      allow(Serega::SeregaPlugins::Root).to receive(:apply)
    end

    it "loads the plugin with its options and returns the plugin module" do
      expect(load_plugin).to be Serega::SeregaPlugins::Root

      expect(Serega::SeregaPlugins::Root).to have_received(:apply).with(serializer_class, root: :user)
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
