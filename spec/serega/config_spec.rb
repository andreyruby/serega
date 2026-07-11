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

  describe "#hide_by_default" do
    it "returns default value" do
      expect(config.hide_by_default).to be false
    end
  end

  describe "#auto_preload_excluded_methods" do
    it "returns default value" do
      expect(config.auto_preload_excluded_methods).to eq %i[itself]
    end
  end

  describe "#auto_preload_excluded_methods=" do
    it "validates value is an Array of Symbols" do
      expect { config.auto_preload_excluded_methods = [] }.not_to raise_error
      expect { config.auto_preload_excluded_methods = %i[itself current_object] }.not_to raise_error
      expect { config.auto_preload_excluded_methods = :itself }
        .to raise_error Serega::SeregaError, "Must be an Array of Symbols, :itself provided"
      expect { config.auto_preload_excluded_methods = ["itself"] }
        .to raise_error Serega::SeregaError, "Must be an Array of Symbols, [\"itself\"] provided"
    end

    it "sets auto_preload_excluded_methods option" do
      config.auto_preload_excluded_methods = %i[current_object]
      expect(config.auto_preload_excluded_methods).to eq %i[current_object]
    end
  end

  describe "#hide_by_default=" do
    it "validates value" do
      expect { config.hide_by_default = false }.not_to raise_error
      expect { config.hide_by_default = true }.not_to raise_error
      expect { config.hide_by_default = :auto }.not_to raise_error
      expect { config.hide_by_default = nil }
        .to raise_error Serega::SeregaError,
          "Must have true, false, or :auto, nil provided"
      expect { config.hide_by_default = [:preload] }
        .to raise_error Serega::SeregaError,
          "Must have true, false, or :auto, [:preload] provided"
    end

    it "sets hide_by_default option" do
      config.hide_by_default = true
      expect(config.hide_by_default).to be true

      config.hide_by_default = false
      expect(config.hide_by_default).to be false

      config.hide_by_default = :auto
      expect(config.hide_by_default).to eq :auto
    end
  end

  describe "#base_serializer" do
    it "returns default value" do
      expect(config.base_serializer).to be_nil
    end
  end

  describe "#base_serializer=" do
    it "validates value is a Serega subclass" do
      expect { config.base_serializer = Serega }.not_to raise_error
      expect { config.base_serializer = Class.new(Serega) }.not_to raise_error
      expect { config.base_serializer = nil }
        .to raise_error Serega::SeregaError, "Must be a Serega subclass, nil provided"
      expect { config.base_serializer = Object }
        .to raise_error Serega::SeregaError, "Must be a Serega subclass, Object provided"
      expect { config.base_serializer = "UserSerializer" }
        .to raise_error Serega::SeregaError, "Must be a Serega subclass, \"UserSerializer\" provided"
    end

    it "sets base_serializer option" do
      base = Class.new(Serega)
      config.base_serializer = base
      expect(config.base_serializer).to equal base
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

  describe "#hash_access" do
    it "returns default value" do
      expect(config.hash_access).to eq(default_mode: :symbol, default_allow_nil: false)
    end
  end

  describe "#hash_access=" do
    it "validates value is a Hash with allowed keys" do
      expect { config.hash_access = :symbol }
        .to raise_error Serega::SeregaError, "Must have Hash value, :symbol provided"

      expect { config.hash_access = {mode: :symbol} }
        .to raise_error Serega::SeregaError,
          "Invalid hash_access option :mode. Allowed options are: :default_allow_nil, :default_mode"
    end

    it "validates :default_mode value" do
      expect { config.hash_access = {default_mode: :fetch} }
        .to raise_error Serega::SeregaError, "Invalid hash_access :default_mode :fetch. Allowed modes: :symbol, :string, :auto"
    end

    it "validates :default_allow_nil value" do
      expect { config.hash_access = {default_allow_nil: nil} }
        .to raise_error Serega::SeregaError, "Invalid hash_access :default_allow_nil nil. Must be a Boolean"
    end

    it "sets hash_access option keeping omitted keys" do
      config.hash_access = {default_mode: :string}
      expect(config.hash_access).to eq(default_mode: :string, default_allow_nil: false)

      config.hash_access = {default_allow_nil: true}
      expect(config.hash_access).to eq(default_mode: :string, default_allow_nil: true)

      config.hash_access = {default_mode: :auto, default_allow_nil: false}
      expect(config.hash_access).to eq(default_mode: :auto, default_allow_nil: false)
    end
  end

  describe "#batch_id_option" do
    it "returns default value" do
      expect(config.batch_id_option).to eq(:id)
    end
  end

  describe "#batch_id_option=" do
    it "validates value is Symbol" do
      expect { config.batch_id_option = "id" }.to raise_error Serega::SeregaError,
        "Must have Symbol value, \"id\" provided"
    end

    it "sets batch_id_option option" do
      config.batch_id_option = :uuid
      expect(config.batch_id_option).to eq :uuid
    end
  end
end
