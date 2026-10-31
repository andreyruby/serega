# frozen_string_literal: true

class Serega
  module AttributeNormalizers # :nodoc:
    #
    # Finds the preloads of an attribute
    #
    class Preloads # :nodoc:
      class << self
        # Preloads of the attribute with options `opts`. `relation` is true
        # for an attribute with a nested serializer: the :serializer option
        # or a block.
        #
        # The value is passed through as provided (Symbol, Array, Hash, or any
        # custom value an ORM understands) — it is the data handed to the
        # serializer's `preload_with` handler.
        def call(opts, relation, method_name, config)
          # Explicit preload option (false or nil disables preloading)
          return opts[:preload] || nil if opts.key?(:preload)

          # Auto-preload the delegated association
          if config.auto_preload.fetch(:has_delegate_option) && opts[:delegate]
            return auto_preload_value(opts[:delegate][:to], config)
          end

          # Auto-preload the nested serializer's association
          if config.auto_preload.fetch(:has_serializer_option) && relation && !opts.key?(:batch)
            return auto_preload_value(method_name, config)
          end

          nil
        end

        private

        # Skips auto-preloading of methods that return the object
        # itself (:itself by default) — they are not associations,
        # so preloading them would fail or make no sense.
        def auto_preload_value(preload_method, config)
          return nil if config.auto_preload_excluded_methods.include?(preload_method.to_sym)

          preload_method
        end
      end
    end
  end
end
