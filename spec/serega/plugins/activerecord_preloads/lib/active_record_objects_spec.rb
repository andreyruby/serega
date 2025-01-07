# frozen_string_literal: true

require "support/activerecord"

load_plugin_code :activerecord_preloads

RSpec.describe Serega::SeregaPlugins::ActiverecordPreloads do
  describe described_class::ActiveRecordObjects do
    let(:plugin) { Serega::SeregaPlugins::ActiverecordPreloads }

    describe ".call" do
      let(:obj1) { AR::User.new }
      let(:obj2) { AR::User.new }

      it "extracts AR objects from Arrays, Hashes, Objects" do
        expect(described_class.call(foo: :bar)).to eq []
        expect(described_class.call(foo: obj1, bar: obj2)).to eq [obj1, obj2]
        expect(described_class.call(foo: [obj1], bar: [obj2])).to eq [obj1, obj2]
        expect(described_class.call([obj1, obj2])).to eq [obj1, obj2]
        expect(described_class.call(foo: {bar: obj1}, bazz: [obj2])).to eq [obj1, obj2]
      end
    end
  end
end
