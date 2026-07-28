# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :string_modifiers
    #
    # Allows to specify modifiers as strings.
    #
    # Serialized attributes must be split with `,` and nested attributes can be defined inside brackets `(`, `)`.
    #
    # @example
    #   PostSerializer.plugin :string_modifiers
    #   PostSerializer.new(only: "id,user(id,username)").to_h(post)
    #   PostSerializer.new(except: "user(username,email)").to_h(post)
    #   PostSerializer.new(with: "user(email)").to_h(post)
    #
    #   # Modifiers can still be provided old way with nested hashes or arrays.
    #   PostSerializer.new(with: {user: %i[email, username]}).to_h(post)
    #
    module StringModifiers
      #
      # Modifiers parser
      #
      # @private
      class ParseStringModifiers
        COMMA = ","
        COMMA_CODEPOINT = COMMA.ord
        LPAREN = "("
        LPAREN_CODEPOINT = LPAREN.ord
        RPAREN = ")"
        RPAREN_CODEPOINT = RPAREN.ord
        private_constant :COMMA, :LPAREN, :RPAREN, :COMMA_CODEPOINT, :LPAREN_CODEPOINT, :RPAREN_CODEPOINT

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
            attribute_storage = result
            path_stack = (fields.include?(LPAREN) || fields.include?(RPAREN)) ? [] : nil

            start_index = 0
            end_index = 0
            fields.each_codepoint do |codepoint|
              case codepoint
              when COMMA_CODEPOINT
                attribute = extract_attribute(fields, start_index, end_index)
                add_attribute(attribute_storage, attribute, FROZEN_EMPTY_HASH) if attribute
                start_index = end_index + 1
              when LPAREN_CODEPOINT
                attribute = extract_attribute(fields, start_index, end_index)
                if attribute
                  attribute_storage = add_attribute(attribute_storage, attribute, {})
                  path_stack.push(attribute)
                end
                start_index = end_index + 1
              when RPAREN_CODEPOINT
                attribute = extract_attribute(fields, start_index, end_index)
                add_attribute(attribute_storage, attribute, FROZEN_EMPTY_HASH) if attribute
                path_stack.pop
                attribute_storage = dig?(result, path_stack)
                start_index = end_index + 1
              end

              end_index += 1
            end

            attribute = extract_attribute(fields, start_index, end_index)
            add_attribute(attribute_storage, attribute, FROZEN_EMPTY_HASH) if attribute

            result
          end

          private

          def extract_attribute(fields, start_index, end_index)
            attribute = fields[start_index, end_index - start_index]
            attribute.strip!
            attribute.empty? ? nil : attribute.to_sym
          end

          def add_attribute(storage, attribute, nested_attributes = FROZEN_EMPTY_HASH)
            storage[attribute] = nested_attributes
          end

          def dig?(hash, path)
            return hash if !path || path.empty?

            path.each do |point|
              hash = hash[point]
            end

            hash
          end
        end
      end
    end
  end
end
