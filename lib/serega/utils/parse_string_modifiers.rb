# frozen_string_literal: true

class Serega
  module SeregaUtils # :nodoc:
    #
    # Parses fields listed in one String, with nested fields in parentheses
    #
    class ParseStringModifiers # :nodoc:
      SEPARATOR = /[,()]/
      COMMA = ",".ord
      LPAREN = "(".ord
      private_constant :SEPARATOR, :COMMA, :LPAREN

      class << self
        #
        # Parses string modifiers
        #
        # @param fields [String]
        #
        # @return [Hash] parsed modifiers in form of nested hash
        #
        # @example
        #   parse("user") => { user: {} }
        #   parse("user(id)") => { user: { id: {} } }
        #   parse("user(id,name)") => { user: { id: {}, name: {} } }
        #   parse("user,comments") => { user: {}, comments: {} }
        #   parse("user(comments(text))") => { user: { comments: { text: {} } } }
        def parse(fields)
          result = {}
          storage = result
          parent_storages = nil
          start = 0

          while (index = fields.byteindex(SEPARATOR, start))
            name = extract_name(fields, start, index)
            separator = fields.getbyte(index)

            if separator == COMMA
              storage[name] = FROZEN_EMPTY_HASH if name
            elsif separator == LPAREN
              if name
                (parent_storages ||= []) << storage
                storage = storage[name] = {}
              end
            else
              storage[name] = FROZEN_EMPTY_HASH if name
              storage = parent_storages&.pop || result
            end

            start = index + 1
          end

          name = extract_name(fields, start, fields.bytesize)
          storage[name] = FROZEN_EMPTY_HASH if name

          result
        end

        private

        def extract_name(fields, start, finish)
          name = fields.byteslice(start, finish - start)
          name.strip!
          name.empty? ? nil : name.to_sym
        end
      end
    end
  end
end
