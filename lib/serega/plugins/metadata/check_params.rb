# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator of the path, the options and the block of a meta attribute
        #
        class CheckParams # :nodoc:
          # Options of `meta_attribute`
          KEYS = %i[const value hide_nil hide_empty].freeze

          # Characters allowed in each key of the path
          PATH_FORMAT = /\A[\w~-]+\z/

          # Signatures of a value or a block: up to two parameters, the objects
          # and the context
          VALID_SIGNATURES = %w[0 1 2].freeze

          class << self
            # Checks the meta attribute params. `check_path` is
            # `config.check_attribute_name`.
            def call(path, opts, block, check_path)
              path.each { |key| check_path_key(key) } if check_path
              SeregaValidations::Utils::CheckAllowedKeys.call(opts, KEYS, :meta_attribute)
              check_true(opts, :hide_empty)
              check_true(opts, :hide_nil)
              check_value_source(opts, block)
              check_value(opts[:value]) if opts.key?(:value)
              check_block(block) if block
            end

            private

            def check_path_key(key)
              key = key.to_s
              return if PATH_FORMAT.match?(key)

              raise SeregaError,
                "Invalid metadata path #{key.inspect}. Allowed characters: \"a-z\", \"A-Z\", \"0-9\", \"_\", \"-\", \"~\""
            end

            def check_true(opts, key)
              return unless opts.key?(key)

              value = opts[key]
              raise SeregaError, "Invalid option #{key.inspect} => #{value.inspect}. Must be true" unless value == true
            end

            # Exactly one of :value, :const and the block gives the value
            def check_value_source(opts, block)
              value = opts.key?(:value)
              const = opts.key?(:const)

              raise SeregaError, "Option :value can not be used together with option :const" if value && const
              raise SeregaError, "Option :value can not be used together with block" if value && block
              raise SeregaError, "Option :const can not be used together with block" if const && block
              raise SeregaError, "Please provide block argument or add :value or :const option" unless value || const || block
            end

            def check_value(value)
              raise SeregaError, "Option :value value must be a Proc or respond to #call" unless value.respond_to?(:call)

              signature = SeregaUtils::MethodSignature.call(value, pos_limit: 2, keyword_args: [])
              return if VALID_SIGNATURES.include?(signature)

              raise SeregaError, "Option :value value can have maximum 2 parameters (object(s), context)"
            end

            def check_block(block)
              signature = SeregaUtils::MethodSignature.call(block, pos_limit: 2, keyword_args: [])
              raise SeregaError, "Block can have maximum two parameters (object(s), context)" unless VALID_SIGNATURES.include?(signature)
            end
          end
        end
      end
    end
  end
end
