# frozen_string_literal: true

load_plugin_code :preloads, :activerecord_preloads

RSpec.describe Serega::SeregaPlugins::ActiverecordPreloads do
  describe "loading" do
    let(:serializer) { Class.new(Serega) }

    it "loads successfully" do
      expect { serializer.plugin(:activerecord_preloads) }.not_to raise_error
    end

    it "raises error if loaded after :batch plugin" do
      serializer.plugin(:batch)
      error = "Plugin :activerecord_preloads must be loaded before the :batch plugin"
      expect { serializer.plugin(:activerecord_preloads) }.to raise_error Serega::SeregaError, error
    end

    it "raises error when any option was provided" do
      error = "Plugin :activerecord_preloads does not accept the :foo option. No options are allowed"
      expect { serializer.plugin(:activerecord_preloads, foo: :bar) }.to raise_error Serega::SeregaError, error
    end
  end

  describe "InstanceMethods" do
    let(:serializer_class) do
      Class.new(Serega) do
        plugin :activerecord_preloads

        attribute :itself
      end
    end

    let(:serializer) { serializer_class.new }
    let(:preloader) { Serega::SeregaPlugins::ActiverecordPreloads::Preloader }

    before { allow(preloader).to receive(:preload) }

    describe "#preload_associations_to" do
      subject(:preload) { serializer.preload_associations_to(object) }

      let(:preloads) { "PRELOADS" }
      let(:object) { "OBJECT" }

      before { allow(serializer).to receive(:preloads).and_return(preloads) }

      it "adds preloads to object" do
        preload
        expect(preloader).to have_received(:preload).with(object, preloads)
      end

      context "with nil object" do
        let(:object) { nil }

        it "skips preloading" do
          preload
          expect(preloader).not_to have_received(:preload)
        end
      end

      context "with empty array" do
        let(:object) { [] }

        it "skips preloading" do
          preload
          expect(preloader).not_to have_received(:preload)
        end
      end

      context "with nothing to preload" do
        let(:preloads) { {} }

        it "skips preloading" do
          preload
          expect(preloader).not_to have_received(:preload)
        end
      end
    end

    describe "#to_h" do
      subject(:to_h) { serializer.to_h(object) }

      let(:preloads) { "PRELOADS" }
      let(:object) { "OBJECT" }

      before { allow(serializer).to receive(:preload_associations_to) }

      it "preloads associations before serialization" do
        expect(serializer.to_h(object)[:itself]).to eq(object)
        expect(serializer).to have_received(:preload_associations_to).with(object)
      end
    end
  end
end
