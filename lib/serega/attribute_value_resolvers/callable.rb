# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Value of attributes with the :value option. Calls the callable with
    # the arguments that its parameters take. It is no resolver: generated
    # code calls the callable itself, with #code.
    #
    class Callable # :nodoc:
      # The :value callable
      attr_reader :callable

      def initialize(callable)
        @callable = callable
        @signature = SeregaUtils::MethodSignature.call(callable, pos_limit: 2, keyword_args: [:ctx])
      end

      # Calls the callable with the object, the context and the batches that
      # its parameters take
      def call(object, ctx:, batches:)
        case @signature
        when "1" then @callable.call(object)
        when "1_ctx" then @callable.call(object, ctx: ctx)
        when "1_batches" then @callable.call(object, batches: batches)
        when "1_batches_ctx" then @callable.call(object, ctx: ctx, batches: batches)
        when "2" then @callable.call(object, ctx)
        when "2_batches_ctx" then @callable.call(object, ctx, ctx: ctx, batches: batches)
        else @callable.call # no parameters
        end
      end

      # Ruby code that calls the callable, which `callable_variable` holds,
      # the same way as #call. `batches_variable` holds the loaded batches.
      def code(source_variable, callable_variable, batches_variable)
        arguments =
          case @signature
          when "1" then source_variable
          when "1_ctx" then "#{source_variable}, ctx: context"
          when "1_batches" then "#{source_variable}, batches: #{batches_variable}"
          when "1_batches_ctx" then "#{source_variable}, ctx: context, batches: #{batches_variable}"
          when "2" then "#{source_variable}, context"
          when "2_batches_ctx" then "#{source_variable}, context, ctx: context, batches: #{batches_variable}"
          end
        arguments ? "#{callable_variable}.call(#{arguments})" : "#{callable_variable}.call"
      end
    end
  end
end
