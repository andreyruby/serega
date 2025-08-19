# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe ".config" do
    subject(:config) { serializer_class.config }

    it "generates default config" do
      expect(config.__send__(:opts).keys).to match_array %i[
        plugins
        initiate_keys
        serialize_keys
        attribute_keys
        check_attribute_name
        check_initiate_params
        delegate_default_allow_nil
        max_cached_plans_per_serializer_count
        auto_preload
        auto_hide
      ]

      expect(config.plugins).to eq []
      expect(config.serialize_keys).to match_array(%i[context many])
      expect(config.initiate_keys).to match_array(%i[only except with check_initiate_params])
      expect(config.attribute_keys).to match_array(
        %i[
          method
          value
          serializer
          many
          hide
          const
          delegate
          default
          preload
          preload_path
          batch
        ]
      )
      expect(config.check_attribute_name).to be true
      expect(config.check_initiate_params).to be true
      expect(config.delegate_default_allow_nil).to be false
      expect(config.max_cached_plans_per_serializer_count).to eq 0
    end
  end

  describe ".inherited" do
    it "inherits config" do
      parent_ser = Class.new(described_class)
      child_ser = Class.new(parent_ser)
      parent = parent_ser.config
      child = child_ser.config

      # Check config values are inherited
      expect(child.__send__(:opts)).to eq parent.__send__(:opts)
      expect(child.__send__(:opts)).not_to equal parent.__send__(:opts)

      # Check child config does not overwrite parent config values
      child.attribute_keys << :foo
      expect(parent.attribute_keys).not_to include :foo

      # Check child config does not adds new keys to parent config
      child.__send__(:opts)[:foo] = 123
      expect(parent.__send__(:opts)).not_to have_key(:foo)

      # Check child config is a subclass of parent config
      expect(child.class.superclass).to eq parent.class
    end

    it "inherits attributes" do
      parent = Class.new(described_class)
      parent.attribute(:foo)

      # Check attributes are copied to child attributes
      child = Class.new(parent)
      expect(child.attributes[:foo].class.superclass).to eq parent.attributes[:foo].class
    end

    it "inherits same batch loaders" do
      parent = Class.new(described_class)
      parent.batch(:foo, proc { |objects| objects })

      child = Class.new(parent)
      expect(child.batch_loaders).to have_key(:foo)
      expect(child.batch_loaders[:foo].load(1, nil)).to eq 1
    end

    it "inherits serialization class" do
      parent = Class.new(described_class)
      child = Class.new(parent)

      expect(child::SeregaObjectSerializer.superclass).to eq parent::SeregaObjectSerializer
    end
  end

  describe ".plugin" do
    let(:plugin) { Module.new }

    it "runs plugin callbacks" do
      opts = {foo: :bar}
      allow(plugin).to receive_messages(
        before_load_plugin: nil,
        load_plugin: nil,
        after_load_plugin: nil
      )
      serializer_class.plugin(plugin, **opts)

      expect(plugin).to have_received(:before_load_plugin).with(serializer_class, opts)
      expect(plugin).to have_received(:load_plugin).with(serializer_class, opts)
      expect(plugin).to have_received(:after_load_plugin).with(serializer_class, opts)
    end

    it "loads not registered plugins modules" do
      serializer_class.plugin plugin
      expect(serializer_class.config.plugins).to eq [plugin]
    end

    it "loads registered plugins using plugin_name" do
      plugin.instance_exec do
        def self.plugin_name
          :test
        end
      end

      Serega::SeregaPlugins.register_plugin(plugin.plugin_name, plugin)

      serializer_class.plugin(:test)
      expect(serializer_class.config.plugins).to eq [:test]
    end

    it "raises error if plugin is already loaded" do
      serializer_class.plugin(plugin)
      expect { serializer_class.plugin(plugin) }.to raise_error Serega::SeregaError, "This plugin is already loaded"
    end
  end

  describe ".plugin_used?" do
    it "tells if plugin has been already loaded" do
      plugin = Module.new
      expect(serializer_class.plugin_used?(plugin)).to be false
      serializer_class.plugin(plugin)
      expect(serializer_class.plugin_used?(plugin)).to be true
    end

    it "tells if plugin has been already loaded when plugin has name" do
      plugin = Module.new do
        def self.plugin_name
          :test
        end
      end
      expect(serializer_class.plugin_used?(plugin)).to be false
      serializer_class.plugin(plugin)
      expect(serializer_class.plugin_used?(plugin)).to be true
    end

    it "tells if plugin has been already loaded when given plugin name" do
      plugin = Module.new do
        def self.plugin_name
          :test
        end
      end

      Serega::SeregaPlugins.register_plugin(plugin.plugin_name, plugin)

      expect(serializer_class.plugin_used?(:test)).to be false
      serializer_class.plugin(:test)
      expect(serializer_class.plugin_used?(:test)).to be true
    end
  end

  describe ".attribute" do
    it "adds new attribute" do
      attribute = serializer_class.attribute "foo"
      expect(serializer_class.attributes).to eq(foo: attribute)
    end
  end

  describe ".attributes" do
    it "returns empty hash when no attributes added" do
      expect(serializer_class.attributes).to eq({})
    end

    it "returns list of added attributes" do
      foo = serializer_class.attribute :foo
      bar = serializer_class.attribute :bar

      expect(serializer_class.attributes).to eq(foo: foo, bar: bar)
    end
  end

  describe "serialization methods" do
    let(:serializer_class) do
      Class.new(described_class) do
        attribute(:obj) { |obj| obj }
        attribute(:ctx) { |obj, ctx| ctx[:data] }
        attribute(:except, const: "EXCEPT")
      end
    end

    let(:modifiers) { {except: :except} }
    let(:serialize_opts) { {context: {data: "bar"}} }

    let(:serializer) { serializer_class.new(modifiers) }

    describe "#call" do
      it "returns serialized response" do
        expect(serializer.call("foo", serialize_opts)).to eq({obj: "foo", ctx: "bar"})
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          expect(serializer.call("foo", serialize_opts)).to eq({obj: "foo", ctx: "bar"})
        end
      end
    end

    describe "#to_h" do
      it "returns serialized response same as .call method" do
        expect(serializer.to_h("foo", serialize_opts)).to eq({obj: "foo", ctx: "bar"})
      end
    end

    describe ".call" do
      it "returns serialized to response" do
        expect(serializer_class.call("foo", modifiers.merge(serialize_opts))).to eq({obj: "foo", ctx: "bar"})
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          expect(serializer_class.call("foo", modifiers.merge(serialize_opts))).to eq({obj: "foo", ctx: "bar"})
        end
      end
    end

    describe ".to_h" do
      it "returns serialized response same as .call method" do
        expect(serializer_class.to_h("foo", modifiers.merge(serialize_opts))).to eq({obj: "foo", ctx: "bar"})
      end
    end
  end

  describe "validating initiate params" do
    let(:validator) { instance_double(serializer_class::CheckInitiateParams, validate: nil) }
    let(:modifiers) { {only: "foo"} }

    before do
      allow(serializer_class::CheckInitiateParams).to receive(:new).and_return(validator)
    end

    it "validates initiate params by default" do
      serializer_class.to_h(nil, modifiers)

      expect(serializer_class::CheckInitiateParams).to have_received(:new).with(only: {foo: {}})
      expect(validator).to have_received(:validate)
    end

    it "allows to disable validation via config option" do
      serializer_class.config.check_initiate_params = false
      serializer_class.to_h(nil, modifiers)

      expect(serializer_class::CheckInitiateParams).not_to have_received(:new)
    end

    it "allows to disable validation via check_initiate_params param" do
      serializer_class.to_h(nil, **modifiers, check_initiate_params: false)

      expect(serializer_class::CheckInitiateParams).not_to have_received(:new)
    end
  end

  describe "validating serialize params" do
    let(:validator) { instance_double(serializer_class::CheckSerializeParams, validate: nil) }
    let(:params) { {only: {}, except: {}, with: {}, context: {foo: "bar"}, a: 1} }

    before do
      allow(serializer_class::CheckSerializeParams).to receive(:new).and_return(validator)
    end

    it "selects serialize params (not modifiers params) and validates them" do
      serializer_class.to_h(nil, params)

      expect(serializer_class::CheckSerializeParams).to have_received(:new).with(context: {foo: "bar"}, a: 1)
      expect(validator).to have_received(:validate)
    end
  end

  describe "serialization" do
    subject(:result) { user_serializer.new(**modifiers).to_h(user, context: context) }

    let(:user_serializer) do
      Class.new(Serega) do
        attribute :first_name
        attribute :last_name
      end
    end
    let(:context) { {} }
    let(:modifiers) { {} }

    context "with empty array" do
      let(:user) { [] }

      it "returns empty array" do
        expect(result).to eq([])
      end
    end

    context "with object with attributes" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }

      it "returns hash" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with object with relation" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      it "returns hash with relations" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT"}})
      end

      it "returns hash with relations when manually specifying :many option" do
        user_serializer.attribute :comment, serializer: comment_serializer, many: false
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {text: "TEXT"}})
      end
    end

    context "with object with array relation" do
      let(:comments) { [double(text: "TEXT")] }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: comments) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comments, serializer: child_serializer
        end
      end

      it "returns hash with relations" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: [{text: "TEXT"}]})
      end

      it "returns hash with relations when manually specifying :many option" do
        user_serializer.attribute :comments, serializer: comment_serializer, many: true
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comments: [{text: "TEXT"}]})
      end
    end

    context "with object with hidden attribute" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name
        end
      end

      it "returns serialized object without hidden attributes" do
        expect(result).to eq({last_name: "LAST_NAME"})
      end
    end

    context "with `:with` context option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name
        end
      end

      let(:modifiers) { {with: :first_name} }

      it "returns specified in `:with` option hidden attributes" do
        expect(result).to include({first_name: "FIRST_NAME"})
      end
    end

    context "with `:only` context option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name
        end
      end

      let(:modifiers) { {only: :first_name} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({first_name: "FIRST_NAME"})
      end
    end

    context "with :except option" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:modifiers) { {except: :first_name} }

      it "returns hash without :excepted attributes" do
        expect(result).to eq({last_name: "LAST_NAME"})
      end
    end

    context "with `:with` context option provided as Array" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name, hide: true
        end
      end

      let(:modifiers) { {with: %w[first_name last_name]} }

      it "returns specified in `:with` option hidden attributes" do
        expect(result).to include({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with `:only` context option provided as Array" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", middle_name: "MIDDLE_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, hide: true
          attribute :last_name, hide: true
          attribute :middle_name
        end
      end

      let(:modifiers) { {only: %i[first_name last_name]} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with :except option provided as Array" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", middle_name: "MIDDLE_NAME") }
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :middle_name
        end
      end

      let(:modifiers) { {except: %i[first_name last_name]} }

      it "returns hash without :excepted attributes" do
        expect(result).to eq({middle_name: "MIDDLE_NAME"})
      end
    end

    context "with `:with` context option provided as Hash" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text, hide: true
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name, hide: true
          attribute :comment, serializer: child_serializer, hide: true
        end
      end

      let(:modifiers) { {with: {comment: :text}} }

      it "returns hash with additional attributes specified in `:with` option" do
        expect(result).to include({first_name: "FIRST_NAME", comment: {text: "TEXT"}})
      end
    end

    context "with `:only` context option provided as Hash" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {only: {comment: :text}} }

      it "returns hash with `only` selected attributes" do
        expect(result).to eq({comment: {text: "TEXT"}})
      end
    end

    context "with :except option provided as Hash" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {except: {comment: :text}} }

      it "returns hash without excepted attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: {}})
      end
    end

    context "with :except of relation" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {except: :comment} }

      it "returns hash without excepted attributes" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with :only relation" do
      let(:comment) { double(text: "TEXT") }
      let(:comment_serializer) do
        Class.new(Serega) do
          attribute :text
        end
      end

      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME", comment: comment) }
      let(:user_serializer) do
        child_serializer = comment_serializer
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name
          attribute :comment, serializer: child_serializer
        end
      end

      let(:modifiers) { {only: :comment} }

      it "returns hash with only requested fields and all fields of requested relation" do
        expect(result).to eq({comment: {text: "TEXT"}})
      end
    end
  end

  describe "Preloads functionality" do
    let(:serializer_class) { Class.new(described_class) }

    describe "instance methods" do
      it "adds #preloads method" do
        serializer = serializer_class.new
        expect(serializer).to respond_to(:preloads)
      end

      it "returns empty hash when no preloads defined" do
        serializer_class.attribute :name
        serializer = serializer_class.new
        expect(serializer.preloads).to eq({})
      end

      it "returns preloads hash when preloads defined" do
        serializer_class.attribute :name, preload: :user_profile
        serializer = serializer_class.new
        expect(serializer.preloads).to eq({user_profile: {}})
      end
    end

    describe "attribute preloads" do
      it "allows manual preload specification" do
        serializer_class.attribute :name, preload: :user_profile
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to eq({user_profile: {}})
      end

      it "auto-preloads for delegate when configured" do
        serializer_class.config.auto_preload = {has_delegate_option: true}
        serializer_class.attribute :name, delegate: {to: :profile}
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to eq({profile: {}})
      end

      it "auto-preloads for serializer when configured" do
        other_serializer = Class.new(described_class)
        serializer_class.config.auto_preload = {has_serializer_option: true}
        serializer_class.attribute :profile, serializer: other_serializer
        attribute = serializer_class.attributes[:profile]
        expect(attribute.preloads).to eq({profile: {}})
      end

      it "auto-hides attributes with preloads when configured" do
        serializer_class.config.auto_hide = {has_preload_option: true}
        serializer_class.attribute :name, preload: :user_profile
        attribute = serializer_class.attributes[:name]
        expect(attribute.hide).to be true
      end

      it "allows disabling preloads with false" do
        serializer_class.attribute :name, preload: false
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to be_nil
      end
    end

    describe "validation" do
      it "validates preload option cannot be used with const" do
        expect {
          serializer_class.attribute :name, preload: :profile, const: "value"
        }.to raise_error Serega::SeregaError, "Option :preload can not be used together with option :const"
      end
    end
  end

  describe "Batch functionality" do
    it "allows to specify named batch loader by providing callable value" do
      serializer_class.batch(:foo, proc { |objects| objects })
      block_result = serializer_class.batch_loaders[:foo].load(1, 2)
      expect(block_result).to eq 1
    end

    it "allows to specify named batch loader by providing block" do
      serializer_class.batch(:foo) { |objects, context| [objects, context] }
      block_result = serializer_class.batch_loaders[:foo].load(1, 2)
      expect(block_result).to eq [1, 2]
    end

    it "allows to specify named batch loader by providing block with objects and keyword ctx: parameters" do
      serializer_class.batch(:foo) { |objects, ctx:| [objects, ctx] }
      block_result = serializer_class.batch_loaders[:foo].load(1, 2)
      expect(block_result).to eq [1, 2]
    end

    it "checks only block or only value provided" do
      # no block and no value
      expect { serializer_class.batch(:foo) }
        .to raise_error(Serega::SeregaError, "Batch loader must be defined with a callable value or block")

      # block and value together
      expect { serializer_class.batch(:foo, proc {}) {} }
        .to raise_error(Serega::SeregaError, "Batch loader must be defined with a callable value or block")
    end

    context "with some error in batch loader" do
      subject(:result) { user_serializer.to_h(user) }

      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, batch: proc { |_user| foo } # not existing variable call
        end
      end

      let(:user) { double }

      it "raises error with specified attribute name and serializer class" do
        expect { result }.to raise_error NameError,
          end_with("(when serializing 'first_name' attribute in #{user_serializer})")
      end
    end
  end
end
