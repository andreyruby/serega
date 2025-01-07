# frozen_string_literal: true

RSpec.describe Serega::SeregaConfig do
  let(:serializer_class) { Class.new(Serega) }
  let(:config) { serializer_class.config }

  describe ".serializer_class=" do
    it "assigns @serializer_class" do
      config.class.serializer_class = :foo
      expect(config.class.instance_variable_get(:@serializer_class)).to eq :foo
    end
  end

  describe ".serializer_class" do
    it "returns self @serializer_class" do
      expect(config.class.instance_variable_get(:@serializer_class)).to equal serializer_class
      expect(config.class.serializer_class).to equal serializer_class
    end
  end

  describe "#check_attribute_name=" do
    it "validates value is boolean" do
      expect { config.check_attribute_name = false }.not_to raise_error
      expect { config.check_attribute_name = true }.not_to raise_error
      expect { config.check_attribute_name = nil }
        .to raise_error Serega::SeregaError, "Must have boolean value, #{nil.inspect} provided"
    end
  end

  describe "#delegate_default_allow_nil=" do
    it "validates value is boolean" do
      expect { config.delegate_default_allow_nil = false }.not_to raise_error
      expect { config.delegate_default_allow_nil = true }.not_to raise_error
      expect { config.delegate_default_allow_nil = nil }
        .to raise_error Serega::SeregaError, "Must have boolean value, #{nil.inspect} provided"
    end
  end

  describe "#check_initiate_params=" do
    it "validates value is boolean" do
      expect { config.check_initiate_params = false }.not_to raise_error
      expect { config.check_initiate_params = true }.not_to raise_error
      expect { config.check_initiate_params = nil }
        .to raise_error Serega::SeregaError, "Must have boolean value, #{nil.inspect} provided"
    end
  end

  describe "#max_cached_plans_per_serializer_count=" do
    it "validates value is boolean" do
      expect { config.max_cached_plans_per_serializer_count = 10 }.not_to raise_error
      expect { config.max_cached_plans_per_serializer_count = 0 }.not_to raise_error
      expect { config.max_cached_plans_per_serializer_count = nil }
        .to raise_error Serega::SeregaError, "Must have Integer value, #{nil.inspect} provided"
    end
  end

  describe "#to_json=" do
    it "sets to_json option" do
      value = proc {}
      config.to_json = value
      expect(config.to_json).to eq value
    end
  end

  describe "#from_json=" do
    it "sets from_json option" do
      value = proc {}
      config.from_json = value
      expect(config.from_json).to eq value
    end
  end

  describe "#auto_hide" do
    it "returns default value" do
      expect(config.auto_hide).to eq(has_preload_option: false, has_batch_option: false)
    end
  end

  describe "#auto_hide=" do
    it "validates value is boolean" do
      expect { config.auto_hide = false }.not_to raise_error
      expect { config.auto_hide = true }.not_to raise_error
      expect { config.auto_hide = nil }
        .to raise_error Serega::SeregaError, "Must have boolean value or Hash, nil provided"

      expect { config.auto_hide = {foo: :bar} }
        .to raise_error Serega::SeregaError,
          "Invalid auto_hide option :foo. Allowed options are: :has_batch_option, :has_preload_option"
    end

    it "sets auto_hide option" do
      config.auto_hide = true
      expect(config.auto_hide).to eq(has_preload_option: true, has_batch_option: true)

      config.auto_hide = false
      expect(config.auto_hide).to eq(has_preload_option: false, has_batch_option: false)

      config.auto_hide = {has_preload_option: true}
      expect(config.auto_hide).to eq(has_preload_option: true, has_batch_option: false)

      config.auto_hide = {has_batch_option: true}
      expect(config.auto_hide).to eq(has_preload_option: false, has_batch_option: true)
    end
  end

  describe "#auto_preload=" do
    it "validates value is boolean" do
      expect { config.auto_preload = false }.not_to raise_error
      expect { config.auto_preload = true }.not_to raise_error
      expect { config.auto_preload = nil }
        .to raise_error Serega::SeregaError, "Must have boolean value or Hash, nil provided"

      expect { config.auto_preload = {foo: :bar} }
        .to raise_error Serega::SeregaError,
          "Invalid auto_preload option :foo. Allowed options are: :has_delegate_option, :has_serializer_option"
    end

    it "sets auto_preload option" do
      config.auto_preload = true
      expect(config.auto_preload).to eq(has_delegate_option: true, has_serializer_option: true)

      config.auto_preload = false
      expect(config.auto_preload).to eq(has_delegate_option: false, has_serializer_option: false)

      config.auto_preload = {has_delegate_option: true}
      expect(config.auto_preload).to eq(has_delegate_option: true, has_serializer_option: false)

      config.auto_preload = {has_serializer_option: true}
      expect(config.auto_preload).to eq(has_delegate_option: false, has_serializer_option: true)
    end
  end
end
