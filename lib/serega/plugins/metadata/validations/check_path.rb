# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute :path parameter
        #
        # @private
        class CheckPath
          # Regexp for valid path
          FORMAT = /\A[\w~-]+\z/

          private_constant :FORMAT

          class << self
            #
            # Checks allowed characters.
            # Allowed characters: "a-z", "A-Z", "0-9", "_", "-", "~".
            #
            # @param path [Array<String, Symbol>] Metadata attribute path names
            #
            # @raise [SeregaError] when metadata attribute name has invalid format
            # @return [void]
            #
            def call(path)
              path.each { |attr_name| check_name(attr_name) }
            end

            private

            def check_name(name)
              name = name.to_s

              raise SeregaError, message(name) unless FORMAT.match?(name)
            end

            def message(name)
              <<~MESSAGE.tr("\n", "")
                Invalid metadata path #{name.inspect}.
                 Allowed characters: "a-z", "A-Z", "0-9", "_", "-", "~"
              MESSAGE
            end
          end
        end
      end
    end
  end
end
