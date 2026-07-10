# frozen_string_literal: true

RSpec.describe Serega::SeregaAttributeNormalizer do
  let(:serializer_class) { Class.new(Serega) }
  let(:normalizer) { serializer_class::SeregaAttributeNormalizer }

  describe "#name" do
    it "symbolizes name" do
      attribute = normalizer.new(name: "current_name")
      expect(attribute.name).to eq :current_name
    end
  end

  describe "#method_name" do
    it "returns symbolized :method options" do
      attribute = normalizer.new(name: "current_name", opts: {method: "method"})
      expect(attribute.method_name).to eq :method
    end

    it "returns name when :method option not provided" do
      attribute = normalizer.new(name: "current_name", opts: {})
      expect(attribute.method_name).to eq :current_name
    end
  end

  describe "#many" do
    it "returns provided :many option" do
      expect(normalizer.new(opts: {many: true}).many).to be true
      expect(normalizer.new(opts: {many: false}).many).to be false
      expect(normalizer.new(opts: {}).many).to be_nil
    end

    it "returns saved :many option" do
      norm = normalizer.new(opts: {many: true})
      expect(norm.many).to be true
      expect(norm.instance_variable_get(:@many)).to be true

      norm.instance_variable_set(:@many, nil)
      expect(norm.many).to be_nil
    end
  end

  describe "#default" do
    it "returns provided :default option" do
      expect(normalizer.new(opts: {default: 123, many: true}).default).to eq 123
    end

    it "returns saved :default option" do
      default = []
      norm = normalizer.new(opts: {default: default})
      expect(norm.default).to equal default
      expect(norm.default).to equal norm.default
    end

    it "returns empty array if no default provided, but many: true provided" do
      norm = normalizer.new(opts: {many: true})
      expect(norm.default).to equal Serega::FROZEN_EMPTY_ARRAY
    end
  end

  describe "#hide" do
    it "returns provided :hide option" do
      expect(normalizer.new(opts: {hide: true}).hide).to be true
      expect(normalizer.new(opts: {hide: false}).hide).to be false
      expect(normalizer.new(opts: {}).hide).to be_nil
    end

    it "returns saved :hide option" do
      norm = normalizer.new(opts: {hide: true})

      expect(norm.hide).to be true
      expect(norm.instance_variable_get(:@hide)).to be true

      norm.instance_variable_set(:@hide, nil)
      expect(norm.hide).to be_nil
    end

    context "with hide_by_default: :auto" do
      before { serializer_class.config.hide_by_default = :auto }

      it "hides attribute with :preload" do
        expect(normalizer.new(opts: {preload: :foo}).hide).to be true
      end

      it "hides attribute with :batch" do
        expect(normalizer.new(name: :foo, opts: {batch: true}).hide).to be true
      end

      it "does not hide plain attribute" do
        expect(normalizer.new(opts: {}).hide).to be_nil
      end

      it "does not hide attribute with :preload when preloads resolve to nil" do
        expect(normalizer.new(opts: {preload: false}).hide).to be_nil
      end

      it "hides attribute with empty :batch use list (batch key present)" do
        expect(normalizer.new(name: :foo, opts: {batch: {use: []}}).hide).to be(true)
      end

      it "does not hide attribute when auto preload resolves to an excluded method" do
        serializer_class.config.auto_preload = true
        norm = normalizer.new(name: :statistics, opts: {serializer: "bar", method: :itself})
        expect(norm.hide).to be_nil
      end
    end

    context "with hide_by_default: true" do
      it "returns true for any attribute without explicit hide option" do
        serializer_class.config.hide_by_default = true
        expect(normalizer.new(opts: {}).hide).to be true
      end

      it "returns true for explicit hide: true" do
        serializer_class.config.hide_by_default = true
        expect(normalizer.new(opts: {hide: true}).hide).to be true
      end

      it "returns false for explicit hide: false — attribute-level wins over config" do
        serializer_class.config.hide_by_default = true
        expect(normalizer.new(opts: {hide: false}).hide).to be false
      end
    end
  end

  describe "#serializer" do
    it "returns provided :serializer option" do
      expect(normalizer.new(opts: {serializer: 123}).serializer).to eq 123
    end

    it "returns saved :serializer option" do
      norm = normalizer.new(opts: {serializer: true})

      expect(norm.serializer).to be true
      expect(norm.instance_variable_get(:@serializer)).to be true

      norm.instance_variable_set(:@serializer, nil)
      expect(norm.serializer).to be_nil
    end

    context "with block" do
      let(:base_serializer) { Class.new(Serega) }

      before { serializer_class.config.base_serializer = base_serializer }

      def nested_serializer_for(block, opts: {})
        normalizer.new(name: :author, opts: opts, block: block).serializer
      end

      it "builds an anonymous nested serializer inherited from config.base_serializer" do
        nested = nested_serializer_for(proc { attribute :name })

        expect(nested).to be < base_serializer
        expect(nested.attributes.keys).to eq [:name]
      end

      it "prefers the :base_serializer attribute option over config" do
        other_base = Class.new(Serega)
        nested = nested_serializer_for(proc { attribute :name }, opts: {base_serializer: other_base})

        expect(nested).to be < other_base
      end

      it "raises when no base serializer is chosen" do
        plain_serializer = Class.new(Serega)
        plain_normalizer = plain_serializer::SeregaAttributeNormalizer.new(name: :author, opts: {}, block: proc { attribute :name })

        expect { plain_normalizer.serializer }.to raise_error Serega::SeregaError,
          "Attribute block requires a base serializer for the nested serializer." \
          " Provide the `base_serializer: <SerializerClass>` attribute option" \
          " or set `config.base_serializer = <SerializerClass>`"
      end

      it "does not inherit from the current serializer and takes none of its attributes" do
        serializer_class.attribute :id
        nested = nested_serializer_for(proc { attribute :name })

        expect(nested).not_to be < serializer_class
        expect(nested.attributes.keys).to eq [:name]
      end

      it "raises an explaining error when the block defines no attributes" do
        expect { nested_serializer_for(proc {}) }
          .to raise_error Serega::SeregaError, Serega::SeregaValidations::Attribute::CheckBlock::ERROR_MESSAGE
      end

      it "allows a base serializer with its own block attributes when not cyclic" do
        base_serializer.config.base_serializer = Class.new(Serega)
        base_serializer.attribute(:meta, method: :itself) { attribute :version }

        nested = nested_serializer_for(proc { attribute :name })

        expect(nested.attributes.keys).to eq %i[meta name]
      end

      it "raises when the base serializer transitively contains the block attribute being built" do
        cyclic_base = Class.new(Serega)
        cyclic_base.config.base_serializer = cyclic_base
        cyclic_base.attribute(:meta, method: :itself) { attribute :version }

        expect { Class.new(cyclic_base) }.to raise_error Serega::SeregaError,
          "Can not define a nested serializer for attribute :meta —" \
          " its base serializer #{cyclic_base.inspect} (transitively)" \
          " contains this same block attribute (cyclic definition)"
      end

      it "raises when the cycle goes through another base serializer" do
        first_base = Class.new(Serega)
        second_base = Class.new(Serega)
        first_base.config.base_serializer = second_base
        second_base.config.base_serializer = first_base

        # each definition completes — the other base has no block attributes yet
        first_base.attribute(:meta, method: :itself) { attribute :version }
        second_base.attribute(:info, method: :itself) { attribute :details }

        # copying :meta builds its nested serializer from second_base, which
        # copies :info, whose nested serializer is built from first_base,
        # which copies :meta again — the cycle closes
        expect { Class.new(first_base) }.to raise_error Serega::SeregaError,
          "Can not define a nested serializer for attribute :meta —" \
          " its base serializer #{second_base.inspect} (transitively)" \
          " contains this same block attribute (cyclic definition)"
      end

      it "labels the nested serializer with current serializer and attribute names" do
        nested = nested_serializer_for(proc { attribute :name })

        expect(nested.inspect).to eq "#{serializer_class.inspect}.<author>"
        expect(nested.to_s).to eq "#{serializer_class.inspect}.<author>"
      end

      it "inherits base serializer plugins" do
        base_serializer.plugin :camel_case
        nested = nested_serializer_for(proc { attribute :name })

        expect(nested.plugin_used?(:camel_case)).to be true
      end

      it "inherits base serializer config without sharing it" do
        base_serializer.config.auto_preload = {has_serializer_option: true}
        nested = nested_serializer_for(proc { attribute :name })

        expect(nested.config.auto_preload).to eq(has_delegate_option: false, has_serializer_option: true)

        nested.config.auto_preload = false
        expect(base_serializer.config.auto_preload).to eq(has_delegate_option: false, has_serializer_option: true)
      end

      it "inherits base serializer attributes, batch loaders and preload handler" do
        handler = proc { |objects, preloads| [objects, preloads] }
        base_serializer.attribute :id
        base_serializer.batch(:stats, proc { |objects| {} })
        base_serializer.preload_with(handler)

        nested = nested_serializer_for(proc { attribute :name })

        expect(nested.attributes.keys).to eq %i[id name]
        expect(nested.batch_loaders.keys).to eq [:stats]
        expect(nested.preload_with).to equal handler
      end
    end
  end

  describe "#prepare_value_block" do
    it "ignores provided block, it defines a nested serializer, not a value" do
      block = proc {}
      resolver = normalizer.new(name: :length, opts: {}, block: block).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Keyword)
    end

    it "returns provided value option" do
      value = lambda { |one, two| }
      attribute = normalizer.new(opts: {value: value})
      expect(attribute.send(:prepare_value_block)).to equal value
    end

    it "returns resolver generated by :method option" do
      resolver = normalizer.new(opts: {method: :length}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Keyword)
      expect(resolver.call(double(length: 3))).to eq 3
    end

    it "returns resolver generated by :batch option" do
      batches_values = {attr1: {foo: 1}}

      resolver = normalizer.new(
        name: :attr1,
        opts: {
          batch: {id: :itself}
        }
      ).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Batch)
      expect(resolver.call(:foo, batches: batches_values)).to eq 1
    end

    it "returns resolver generated by :const option" do
      const = "123"
      resolver = normalizer.new(opts: {const: const}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Const)
      expect(resolver.call).to be const
    end

    it "returns resolver generated by :delegate option when nil is not allowed" do
      object = double(foo: double(name: "DELEGATED_NAME"))
      delegate = {to: :foo}
      resolver = normalizer.new(name: :name, opts: {delegate: delegate}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Delegate)
      expect(resolver.call(object)).to eq "DELEGATED_NAME"
    end

    it "returns resolver generated by :delegate option that uses :method option" do
      object = double(foo: double(bar: "DELEGATED_NAME"))
      delegate = {to: :foo, method: :bar}
      resolver = normalizer.new(opts: {delegate: delegate}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Delegate)
      expect(resolver.call(object)).to eq "DELEGATED_NAME"
    end

    it "does not raise error when :delegating object is nil and nil is allowed" do
      object1 = double(foo: nil)
      object2 = double(foo: double(name: "NAME"))
      delegate = {to: :foo, allow_nil: true}
      resolver = normalizer.new(name: :name, opts: {delegate: delegate}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::DelegateAllowNil)
      expect(resolver.call(object1)).to be_nil
      expect(resolver.call(object2)).to eq "NAME"
    end

    it "does not raise error when :delegating object is nil and nil is allowed through config" do
      object1 = double(foo: nil)
      object2 = double(foo: double(name: "NAME"))
      delegate = {to: :foo}
      serializer_class.config.delegate_default_allow_nil = true
      resolver = normalizer.new(name: :name, opts: {delegate: delegate}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::DelegateAllowNil)
      expect(resolver.call(object1)).to be_nil
      expect(resolver.call(object2)).to eq "NAME"
    end
  end

  describe "prepare_batch_loaders" do
    def batch_loaders(name:, opts:)
      normalizer.new(name: name, opts: opts).send(:prepare_batch_loaders)
    end

    it "returns array of required batch loader names to send to attribute" do
      # Only explicit :batch attributes need a loader; everything else resolves
      # its value from the record, so the list is empty.
      expect(batch_loaders(name: :foo, opts: {})).to eq %i[]
      expect(batch_loaders(name: :foo, opts: {batch: true})).to eq %i[foo]
      expect(batch_loaders(name: :foo, opts: {batch: proc {}})).to eq %i[foo]
      expect(batch_loaders(name: :foo, opts: {batch: :bar})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: "bar"})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: {use: proc {}}})).to eq %i[foo]
      expect(batch_loaders(name: :foo, opts: {batch: {use: :bar}})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: {use: "bar"}})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: {use: %i[bar bazz]}})).to eq %i[bar bazz]
      expect(batch_loaders(name: :foo, opts: {batch: {use: %w[bar bazz]}})).to eq %i[bar bazz]
    end
  end

  describe "batch-all-attributes experiment" do
    it "registers no synthetic loaders — only explicit :batch attributes have any" do
      child = Class.new(Serega)
      serializer = Class.new(Serega) do
        attribute :title
        attribute :author, serializer: child
        attribute :likes, preload: :likes, value: proc { |o| o }
      end

      # relations, preloads and plain attributes carry no batch loader;
      # their value comes from the record, they are just routed through the
      # batch phase unconditionally by the object serializer.
      expect(serializer.batch_loaders).to be_empty
      expect(serializer.attributes[:title].batch_loaders).to be_empty
      expect(serializer.attributes[:author].batch_loaders).to be_empty
      expect(serializer.attributes[:likes].batch_loaders).to be_empty
    end

    describe "hide_by_default :auto" do
      it "keeps a plain serializer relation visible" do
        child = Class.new(Serega)
        serializer = Class.new(Serega) do
          config.hide_by_default = :auto
          attribute :author, serializer: child
        end
        expect(serializer.attributes[:author].hide).to be_nil
      end

      it "hides attributes declared with :preload or :batch" do
        serializer = Class.new(Serega) do
          config.hide_by_default = :auto
          attribute :a, preload: :a, value: proc { |o| o }
          attribute :b, batch: proc { |objs| objs.to_h { |o| [o, o] } }
        end
        expect(serializer.attributes[:a].hide).to be(true)
        expect(serializer.attributes[:b].hide).to be(true)
      end
    end
  end

  describe "preloads functionality" do
    let(:initials) { {name: :foo, opts: opts, block: nil} }
    let(:opts) { {} }
    let(:norm) { normalizer.new(**initials) }

    describe "#preloads" do
      it "returns nil for regular attributes" do
        expect(norm.preloads).to be_nil
      end

      it "returns nil when provided nil" do
        opts[:preload] = nil
        expect(norm.preloads).to be_nil
      end

      it "returns provided empty hash as-is" do
        opts[:preload] = {}
        expect(norm.preloads).to eq({})
      end

      it "returns provided empty array as-is" do
        opts[:preload] = []
        expect(norm.preloads).to eq([])
      end

      it "returns provided preloads as-is" do
        opts[:preload] = :bar
        expect(norm.preloads).to eq(:bar)
        expect(norm.preloads).to equal norm.preloads
      end

      it "returns provided nested preloads as-is" do
        opts[:preload] = {bar: [:baz, {bat: :qux}]}
        expect(norm.preloads).to eq({bar: [:baz, {bat: :qux}]})
      end

      it "returns automatically found preloads when serializer provided" do
        serializer_class.config.auto_preload = {has_serializer_option: true}
        opts[:serializer] = "bar"
        expect(norm.preloads).to eq(:foo)
      end

      it "returns automatically found preloads when serializer provided and method name provided" do
        serializer_class.config.auto_preload = {has_serializer_option: true}
        opts[:serializer] = "bar"
        opts[:method] = "other"
        expect(norm.preloads).to eq(:other)
      end

      it "returns no auto preloads when serializer and batch provided" do
        serializer_class.config.auto_preload = {has_serializer_option: true}
        opts[:serializer] = "bar"
        opts[:batch] = :batch
        expect(norm.preloads).to be_nil
      end

      it "returns no preloads for attributes with serializer by default" do
        opts[:serializer] = "bar"
        expect(norm.preloads).to be_nil
      end

      it "returns automatically found preloads when :delegate option provided" do
        serializer_class.config.auto_preload = {has_delegate_option: true}
        opts[:delegate] = {to: :bar}
        expect(norm.preloads).to eq(:bar)
      end

      it "returns no preloads for attributes with :delegate option by default" do
        opts[:delegate] = {to: :bar}
        expect(norm.preloads).to be_nil
      end

      it "skips auto preloads for excluded methods of attributes with serializer" do
        serializer_class.config.auto_preload = {has_serializer_option: true}
        opts[:serializer] = "bar"
        opts[:method] = :itself
        expect(norm.preloads).to be_nil
      end

      it "skips auto preloads for excluded methods of attributes with :delegate option" do
        serializer_class.config.auto_preload = {has_delegate_option: true}
        opts[:delegate] = {to: :itself}
        expect(norm.preloads).to be_nil
      end

      it "skips auto preloads for custom auto_preload_excluded_methods" do
        serializer_class.config.auto_preload = {has_serializer_option: true}
        serializer_class.config.auto_preload_excluded_methods = %i[current_object]
        opts[:serializer] = "bar"
        opts[:method] = :current_object
        expect(norm.preloads).to be_nil
      end

      it "skips auto preloads for excluded methods provided as String" do
        serializer_class.config.auto_preload = true
        opts[:delegate] = {to: "itself"}
        expect(norm.preloads).to be_nil
      end

      it "returns no auto preloads for attributes with only :method option" do
        serializer_class.config.auto_preload = true
        opts[:method] = :profile
        expect(norm.preloads).to be_nil
      end
    end
  end
end
