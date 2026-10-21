# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute block parameter
        #
        class CheckBlock # :nodoc:
          class << self
            # Checks block provided with attribute
            # Block must have up to two arguments - object(s) and context.
            #
            #   metadata(:version) { CONSTANT_VERSION }
            #
            #   metadata(:paging) { |scope| { { page: scope.page, per_page: scope.per_page, total_count: scope.total_count } }
            #
            #   metadata(:paging) { |scope, context| { { ... } if context[:pagy] }
            def call(block)
              signature = SeregaUtils::MethodSignature.call(block, pos_limit: 2, keyword_args: [])
              raise SeregaError, block_error unless %w[0 1 2].include?(signature)
            end

            private

            def block_error
              "Block can have maximum two parameters (object(s), context)"
            end
          end
        end
      end
    end
  end
end
