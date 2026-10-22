# frozen_string_literal: true

class Serega
  module AttributeNormalizers # :nodoc:
    #
    # Builds the value resolver of one read: a method call, or a Hash read when
    # a :hash_access option is given
    #
    class HashAccess # :nodoc:
      class << self
        # Resolver that reads `key` of the object. `option` is a :hash_access
        # value: `true`, a Symbol mode or a `{mode:, allow_missing_key:}` Hash;
        # `true` and a Hash without a key take `config.hash_access` defaults.
        # Without the option the resolver calls the method `key`.
        def call(option, key, defaults)
          return AttributeValueResolvers::Keyword.new(key) unless option

          mode, allow_missing_key = parse(option, defaults)
          AttributeValueResolvers::HashAccessKeyword.new(key, mode, allow_missing_key)
        end

        private

        def parse(option, defaults)
          case option
          when true then [defaults.default_mode, defaults.default_allow_missing_key]
          when Symbol then [option, defaults.default_allow_missing_key]
          else
            mode = option.fetch(:mode) { defaults.default_mode }
            allow_missing_key = option.fetch(:allow_missing_key) { defaults.default_allow_missing_key }
            [mode, allow_missing_key]
          end
        end
      end
    end
  end
end
