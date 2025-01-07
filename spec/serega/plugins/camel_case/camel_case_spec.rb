# frozen_string_literal: true

load_plugin_code :camel_case

RSpec.describe Serega::SeregaPlugins::CamelCase do
  describe "loading" do
    let(:serializer) { Class.new(Serega) }

    it "set default camel_case transformation" do
      serializer.plugin :camel_case

      expect(serializer.config.camel_case.transform).to be described_class::TRANSFORM_DEFAULT
    end

    it "set custom camel_case transformation" do
      transform = proc { |_| }
      serializer.plugin :camel_case, transform: transform

      expect(serializer.config.camel_case.transform).to be transform
    end

    it "allows additional attribute option :camel_case" do
      serializer.plugin :camel_case
      expect(serializer.config.attribute_keys).to include :camel_case
    end

    it "raises error if plugin defined with unknown option" do
      serializer = Class.new(Serega)
      expect { serializer.plugin(:camel_case, foo: :bar) }
        .to raise_error Serega::SeregaError, <<~MESSAGE.strip
          Plugin :camel_case does not accept the :foo option. Allowed options:
            - :transform [#call] - Custom transformation
        MESSAGE
    end
  end

  describe "configuration" do
    let(:serializer) { Class.new(Serega) { plugin :camel_case } }

    it "preserves camel_case config" do
      camel_case1 = serializer.config.camel_case
      camel_case2 = serializer.config.camel_case
      expect(camel_case1).to be camel_case2
    end

    it "allows to change camel_case via transformation via #transform= methods" do
      transform = proc { |_| }
      camel_case = serializer.config.camel_case
      camel_case.transform = transform
      expect(camel_case.transform).to eq transform
    end

    it "raises error when provided incorrect params" do
      config = serializer.config.camel_case
      expect { config.transform = :one }.to raise_error "Transform value must respond to #call"
      expect { config.transform = proc {} }.to raise_error "Transform value must respond to #call and accept 1 regular parameter"
      expect { config.transform = proc { |a| } }.not_to raise_error
      expect { config.transform = proc { |a, b| } }.to raise_error "Transform value must respond to #call and accept 1 regular parameter"
      expect { config.transform = proc { |*a| } }.to raise_error "Transform value must respond to #call and accept 1 regular parameter"
      expect { config.transform = proc { |a: nil| } }.to raise_error "Transform value must respond to #call and accept 1 regular parameter"

      c1 = Class.new { def self.call; end } # rubocop:disable Style/SingleLineMethods
      c2 = Class.new { def self.call(one); end } # rubocop:disable Style/SingleLineMethods
      c3 = Class.new { def self.call(one, two); end } # rubocop:disable Style/SingleLineMethods
      expect { config.transform = c1 }.to raise_error "Transform value must respond to #call and accept 1 regular parameter"
      expect { config.transform = c2 }.not_to raise_error
      expect { config.transform = c3 }.to raise_error "Transform value must respond to #call and accept 1 regular parameter"
    end
  end

  describe "validation" do
    let(:serializer) { Class.new(Serega) { plugin :camel_case } }

    it "validates attribute :camel_case option is a boolean" do
      expect { serializer.attribute :foo, camel_case: nil }
        .to raise_error Serega::SeregaError,
          "Attribute option :camel_case must have a boolean value, but NilClass was provided"
    end
  end

  describe "serialization" do
    let(:response) { user_serializer.new.to_h(user) }

    let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", full_name: "FULL_NAME") }
    let(:user_serializer) do
      Class.new(base_serializer) do
        attribute :first_name
        attribute :last_name
        attribute :full_name, camel_case: false
      end
    end

    context "with default camel_case" do
      let(:base_serializer) { Class.new(Serega) { plugin :camel_case } }

      it "serializes keys with camel_cased names" do
        response = user_serializer.new.to_h(user)
        expect(response).to eq(firstName: "FIRST_NAME", lastName: "LAST_NAME", full_name: "FULL_NAME")
      end
    end

    context "with custom camel_case transformation" do
      let(:base_serializer) { Class.new(Serega) { plugin :camel_case, transform: ->(name) { name.to_s.upcase } } }

      it "serializes keys transformed names" do
        response = user_serializer.new.to_h(user)
        expect(response).to eq({FIRST_NAME: "FIRST_NAME", LAST_NAME: "LAST_NAME", full_name: "FULL_NAME"})
      end
    end

    context "with requested fields" do
      let(:base_serializer) { Class.new(Serega) { plugin :camel_case } }

      it "serializes requested keys provided in camelCase" do
        response = user_serializer.new(only: %i[firstName full_name]).to_h(user)
        expect(response).to eq({firstName: "FIRST_NAME", full_name: "FULL_NAME"})
      end
    end
  end
end
