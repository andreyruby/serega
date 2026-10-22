# frozen_string_literal: true

class Serega
  module AttributeNormalizers # :nodoc:
    #
    # Builds the value resolver of the attribute :delegate option
    #
    class Delegate # :nodoc:
      class << self
        # Resolver that reads `delegate[:to]` of the object, then
        # `delegate[:method]` (the attribute method by default) of the result.
        # `delegate: {to_hash_access: ...}` configures hash access for the
        # intermediate (:to) read, `delegate: {hash_access: ...}` for the final
        # (:method) read. A step without its sub-option keeps a plain method
        # read.
        def call(delegate, method_name, config)
          key_method_name = delegate[:method] || method_name
          delegate_to = delegate[:to]
          allow_nil = delegate.fetch(:allow_nil) { config.delegate_default_allow_nil }

          to_access = delegate[:to_hash_access]
          final_access = delegate[:hash_access]
          unless to_access || final_access
            return AttributeValueResolvers::DelegateResolver.get(delegate_to, key_method_name, allow_nil)
          end

          to_step = HashAccess.call(to_access, delegate_to, config.hash_access)
          final_step = HashAccess.call(final_access, key_method_name, config.hash_access)
          AttributeValueResolvers::HashAccessDelegateResolver.get(to_step, final_step, allow_nil)
        end
      end
    end
  end
end
