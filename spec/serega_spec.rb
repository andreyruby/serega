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
        auto_preload_excluded_methods
        hide_by_default
        batch_id_option
        base_serializer
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
          batch
          base_serializer
        ]
      )
      expect(config.check_attribute_name).to be true
      expect(config.check_initiate_params).to be true
      expect(config.delegate_default_allow_nil).to be false
      expect(config.max_cached_plans_per_serializer_count).to eq 0
      expect(config.hide_by_default).to be false
      expect(config.auto_preload).to eq(has_delegate_option: false, has_serializer_option: false)
      expect(config.auto_preload_excluded_methods).to eq %i[itself]
      expect(config.batch_id_option).to eq :id
      expect(config.base_serializer).to be_nil
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

    it "inherits the preload_with handler" do
      handler = proc { |objects, preloads| [objects, preloads] }
      parent = Class.new(described_class)
      parent.preload_with(handler)

      child = Class.new(parent)
      expect(child.preload_with).to equal handler
    end

    it "allows child to override preload_with without affecting parent" do
      parent_handler = proc { |objects, preloads| :parent }
      child_handler = proc { |objects, preloads| :child }
      parent = Class.new(described_class)
      parent.preload_with(parent_handler)

      child = Class.new(parent)
      child.preload_with(child_handler)

      expect(child.preload_with).to equal child_handler
      expect(parent.preload_with).to equal parent_handler
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

  describe ".attribute with block" do
    it "serializes the attribute value with a nested serializer defined by the block" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :first_name

        attribute :statistics, method: :itself do
          attribute :likes_count
          attribute :comments_count
        end
      end

      user = double(first_name: "Kate", likes_count: 10, comments_count: 3)

      expect(user_serializer.to_h(user)).to eq(
        first_name: "Kate",
        statistics: {likes_count: 10, comments_count: 3}
      )
    end

    it "serializes a relation found by attribute name" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :author do
          attribute :name
        end
      end

      user = double(author: double(name: "Kate"))
      expect(user_serializer.to_h(user)).to eq(author: {name: "Kate"})
    end

    it "serializes value found by the :value option" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :author, value: proc { |user| user.creator } do
          attribute :name
        end
      end

      user = double(creator: double(name: "Kate"))
      expect(user_serializer.to_h(user)).to eq(author: {name: "Kate"})
    end

    it "serializes enumerable values as arrays" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :posts do
          attribute :title
        end
      end

      user = double(posts: [double(title: "one"), double(title: "two")])
      expect(user_serializer.to_h(user)).to eq(posts: [{title: "one"}, {title: "two"}])
    end

    it "supports nested serialization modifiers same as regular relations" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :statistics, method: :itself do
          attribute :likes_count
          attribute :comments_count
        end
      end

      user = double(likes_count: 10, comments_count: 3)
      result = user_serializer.to_h(user, only: {statistics: [:likes_count]})
      expect(result).to eq(statistics: {likes_count: 10})
    end

    it "allows to define batch loaders inside the block" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :statistics, method: :itself do
          batch(:stats) do |users|
            users.to_h { |user| [user.id, {likes_count: user.id * 10}] }
          end

          attribute :likes_count, batch: :stats, value: proc { |user, batches:| batches[:stats][user.id][:likes_count] }
        end
      end

      user = double(id: 1)
      expect(user_serializer.to_h(user)).to eq(statistics: {likes_count: 10})
    end

    it "allows to register a preload handler inside the block" do
      preloaded = nil
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        attribute :author do
          preload_with { |objects, preloads| preloaded = [objects, preloads] }
          attribute :name, preload: :profile
        end
      end

      author = double(name: "Kate")
      user_serializer.to_h(double(author: author))
      expect(preloaded).to eq [[author], :profile]
    end

    it "auto-preloads the association same as with the :serializer option" do
      user_serializer = Class.new(Serega) do
        config.base_serializer = Serega
        config.auto_preload = {has_serializer_option: true}

        attribute :author do
          attribute :name
        end
      end

      expect(user_serializer.attributes[:author].preloads).to eq :author
    end

    it "prohibits to use block together with the :serializer option" do
      nested = Class.new(described_class)

      expect {
        Class.new(Serega) do
          attribute(:author, serializer: nested) { attribute :name }
        end
      }.to raise_error Serega::SeregaError, "Option :serializer can not be used together with block"
    end

    it "prohibits blocks with parameters, explaining the changed block behavior" do
      expect {
        Class.new(Serega) do
          attribute(:author) { |user| user.author }
        end
      }.to raise_error Serega::SeregaError, /use the `value: <callable>` option instead/
    end

    it "prohibits blocks that define no attributes, explaining the changed block behavior" do
      expect {
        Class.new(Serega) do
          config.base_serializer = Serega
          attribute(:full_name) { "Kate Smith" }
        end
      }.to raise_error Serega::SeregaError, /use the `value: <callable>` option instead/
    end

    it "raises instead of recursing when subclassing a serializer that is its own base and has a block attribute" do
      base = Class.new(described_class)
      base.config.base_serializer = base
      base.attribute(:meta, method: :itself) { attribute :version }

      expect { Class.new(base) }
        .to raise_error Serega::SeregaError, /cyclic definition/
    end

    it "serializes base serializer attributes together with attributes defined in the block" do
      base = Class.new(Serega) { attribute :id }
      user_serializer = Class.new(Serega) do
        config.base_serializer = base

        attribute :statistics, method: :itself do
          attribute :likes_count
        end
      end

      user = double(id: 1, likes_count: 10)
      expect(user_serializer.to_h(user)).to eq(statistics: {id: 1, likes_count: 10})
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

  describe ".preload_with" do
    it "returns nil when no handler was registered" do
      expect(serializer_class.preload_with).to be_nil
    end

    it "registers and returns a block handler" do
      block = proc { |objects, preloads| [objects, preloads] }
      serializer_class.preload_with(&block)
      expect(serializer_class.preload_with).to equal block
    end

    it "registers a callable value handler" do
      handler = ->(objects, preloads) { [objects, preloads] }
      serializer_class.preload_with(handler)
      expect(serializer_class.preload_with).to equal handler
    end

    it "registers an object responding to #call with two arguments" do
      handler = Class.new do
        def call(objects, preloads)
        end
      end.new
      serializer_class.preload_with(handler)
      expect(serializer_class.preload_with).to equal handler
    end

    it "raises when both a value and a block are given" do
      expect { serializer_class.preload_with(proc { |a, b| }) { |a, b| } }
        .to raise_error Serega::SeregaError, "preload_with accepts a single callable or a block, not both"
    end

    it "raises when the handler is not callable" do
      expect { serializer_class.preload_with(:not_callable) }
        .to raise_error Serega::SeregaError, "preload_with value must be a Proc or respond to #call"
    end

    it "raises when the handler does not accept two positional arguments" do
      error = "preload_with handler must accept two positional arguments: (objects, preloads)"
      expect { serializer_class.preload_with(->(objects) {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.preload_with(->(a, b, c) {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.preload_with(->(objects, ctx:) {}) }.to raise_error Serega::SeregaError, error
    end
  end

  describe "serialization methods" do
    let(:serializer_class) do
      Class.new(described_class) do
        attribute(:obj, value: proc { |obj| obj })
        attribute(:ctx, value: proc { |obj, ctx| ctx[:data] })
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

    describe "#to_data" do
      it "returns a Data object with correct members" do
        result = serializer.to_data("foo", serialize_opts)
        expect(result).to be_a(Data)
        expect(result.obj).to eq "foo"
        expect(result.ctx).to eq "bar"
      end

      it "returns nil when object is nil" do
        expect(serializer.to_data(nil, serialize_opts)).to be_nil
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          result = serializer.to_data("foo", serialize_opts)
          expect(result.obj).to eq "foo"
          expect(result.ctx).to eq "bar"
        end
      end
    end

    describe ".to_data" do
      it "returns a Data object with correct members" do
        result = serializer_class.to_data("foo", modifiers.merge(serialize_opts))
        expect(result).to be_a(Data)
        expect(result.obj).to eq "foo"
        expect(result.ctx).to eq "bar"
      end

      it "returns nil when object is nil" do
        expect(serializer_class.to_data(nil, modifiers.merge(serialize_opts))).to be_nil
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          result = serializer_class.to_data("foo", modifiers.merge(serialize_opts))
          expect(result.obj).to eq "foo"
          expect(result.ctx).to eq "bar"
        end
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

      expect(serializer_class::CheckSerializeParams).to have_received(:new).with(hash_including(context: {foo: "bar"}, a: 1))
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

    context "with Struct object" do
      let(:user_struct) { Struct.new(:first_name, :last_name) }
      let(:user) { user_struct.new("FIRST_NAME", "LAST_NAME") }

      it "serializes Struct as a single object, not as a collection" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end

      it "wraps Struct in an array when :many option is true" do
        expect(user_serializer.to_h(user, many: true))
          .to eq([{first_name: "FIRST_NAME", last_name: "LAST_NAME"}])
      end
    end

    context "with Hash object" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, value: proc { |user| user[:first_name] }
          attribute :last_name, value: proc { |user| user[:last_name] }
        end
      end
      let(:user) { {first_name: "FIRST_NAME", last_name: "LAST_NAME"} }

      it "serializes Hash as a single object, not as a collection of key-value pairs" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with object with Struct relation" do
      let(:statistics_struct) { Struct.new(:likes_count, :comments_count) }
      let(:statistics_serializer) do
        Class.new(Serega) do
          attribute :likes_count
          attribute :comments_count
        end
      end

      let(:user) { double(statistics: statistics_struct.new(10, 20)) }
      let(:user_serializer) do
        child_serializer = statistics_serializer
        Class.new(Serega) do
          attribute :statistics, serializer: child_serializer
        end
      end

      it "serializes Struct relation as a single object, not as a collection" do
        expect(result).to eq({statistics: {likes_count: 10, comments_count: 20}})
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

    describe "attribute preloads" do
      it "allows manual preload specification" do
        serializer_class.attribute :name, preload: :user_profile
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to eq(:user_profile)
      end

      it "auto-preloads for delegate when configured" do
        serializer_class.config.auto_preload = {has_delegate_option: true}
        serializer_class.attribute :name, delegate: {to: :profile}
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to eq(:profile)
      end

      it "auto-preloads for serializer when configured" do
        other_serializer = Class.new(described_class)
        serializer_class.config.auto_preload = {has_serializer_option: true}
        serializer_class.attribute :profile, serializer: other_serializer
        attribute = serializer_class.attributes[:profile]
        expect(attribute.preloads).to eq(:profile)
      end

      it "auto-hides attributes with preloads when configured" do
        serializer_class.config.hide_by_default = :auto
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

      it "validates preload option value can not be `true`" do
        expect {
          serializer_class.attribute :name, preload: true
        }.to raise_error Serega::SeregaError, "Option :preload value can not be `true`"
      end

      it "allows preload option value to be `false`" do
        expect { serializer_class.attribute :name, preload: false }.not_to raise_error
      end
    end

    describe "preload_with wiring" do
      it "invokes the handler with the gathered objects and the attribute preloads" do
        received = nil
        serializer = Class.new(described_class) do
          preload_with { |objects, preloads| received = [objects, preloads] }
          attribute :value, preload: :assoc, value: proc { |obj| obj }
        end

        serializer.to_h([1, 2])
        expect(received).to eq [[1, 2], :assoc]
      end

      it "does not invoke the handler for attributes without preloads" do
        called = false
        serializer = Class.new(described_class) do
          preload_with { |objects, preloads| called = true }
          attribute :value, value: proc { |obj| obj }
        end

        serializer.to_h([1])
        expect(called).to be false
      end

      it "invokes the handler once for an attribute with multiple batch loaders" do
        calls = []
        serializer = Class.new(described_class) do
          preload_with { |objects, preloads| calls << preloads }
          batch(:a) { |objects| objects.to_h { |object| [object, object] } }
          batch(:b) { |objects| objects.to_h { |object| [object, object] } }
          attribute(:value, batch: {use: [:a, :b]}, preload: :assoc, value: proc { |obj, batches:| obj })
        end

        serializer.to_h([1, 2])
        expect(calls).to eq [:assoc]
      end

      it "raises when an attribute declares :preload but no handler is registered" do
        serializer = Class.new(described_class) do
          attribute :value, preload: :assoc, value: proc { |obj| obj }
        end

        error = "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you).\n(when serializing 'value' attribute in #{serializer})"
        expect { serializer.to_h([1]) }.to raise_error Serega::SeregaError, error
      end

      it "raises when a nested attribute declares :preload but its serializer has no handler" do
        child = Class.new(described_class) do
          attribute :name, preload: :profile, value: proc { |obj| obj }
        end
        parent = Class.new(described_class) do
          attribute :child, serializer: child, value: proc { |obj| obj }
        end

        error = "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you).\n(when serializing 'name' attribute in #{child})"
        expect { parent.to_h([1]) }.to raise_error Serega::SeregaError, error
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

    context "when same named batch loader is used by multiple attributes" do
      subject(:result) { user_serializer.to_h([user1, user2], many: true) }

      let(:load_calls) { [] }
      let(:user1) { double(id: 1) }
      let(:user2) { double(id: 2) }

      let(:user_serializer) do
        calls = load_calls
        Class.new(Serega) do
          batch(:stats) do |objects|
            calls << objects.map(&:id)
            objects.each_with_object({}) { |obj, hash| hash[obj.id] = {comments: obj.id * 10, likes: obj.id * 100} }
          end

          attribute(:comments_count, batch: {use: :stats}, value: proc { |obj, batches:| batches[:stats][obj.id][:comments] })
          attribute(:likes_count, batch: {use: :stats}, value: proc { |obj, batches:| batches[:stats][obj.id][:likes] })
        end
      end

      it "loads the shared batch only once" do
        expect(result).to eq [
          {comments_count: 10, likes_count: 100},
          {comments_count: 20, likes_count: 200}
        ]
        expect(load_calls).to eq [[1, 2]]
      end
    end

    context "when serialized objects are a non-Array enumerable" do
      let(:user_serializer) do
        Class.new(Serega) do
          batch(:stats) { |users| users.each_with_object({}) { |user, hash| hash[user.id] = user.id * 10 } }
          attribute(:stat, batch: {use: :stats}, value: proc { |user, batches:| batches[:stats][user.id] })
        end
      end

      it "batch loads objects gathered from the enumerable" do
        users = [double(id: 1), double(id: 2)].each # Enumerator, not an Array
        expect(user_serializer.to_h(users, many: true)).to eq [{stat: 10}, {stat: 20}]
      end
    end

    context "when many: true but a sole object is given" do
      it "wraps the object in an array instead of raising (:many serialization option)" do
        user_serializer = Class.new(Serega) { attribute :id }
        expect(user_serializer.to_h(double(id: 1), many: true)).to eq [{id: 1}]
      end

      it "wraps a sole relation object in an array (:many attribute option)" do
        comment_serializer = Class.new(Serega) { attribute :id }
        user_serializer = Class.new(Serega) do
          attribute :comments, serializer: comment_serializer, many: true
        end
        user = double(comments: double(id: 5)) # a sole object, not a collection
        expect(user_serializer.to_h(user)).to eq(comments: [{id: 5}])
      end
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
