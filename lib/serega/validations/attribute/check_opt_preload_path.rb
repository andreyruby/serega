# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Validator for attribute :preload_path option
      #
      class CheckOptPreloadPath
        class << self
          #
          # Checks preload_path option
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] validation error
          #
          # @return [void]
          #
          def call(opts)
            return if exactly_nil?(opts, :preload_path) # allow to provide nil anyway

            path = opts[:preload_path]
            check_usage_with_other_options(path, opts)
            return unless opts[:serializer]

            check_allowed(path, opts)
          end

          private

          def exactly_nil?(opts, opt_name)
            opts.fetch(opt_name, false).nil?
          end

          def check_allowed(path, opts)
            allowed_paths = SeregaUtils::PreloadPaths.call(opts[:preload])
            check_required_when_many_allowed(path, allowed_paths)
            check_in_allowed(path, allowed_paths)
          end

          def check_usage_with_other_options(path, opts)
            return unless path

            preload = opts[:preload]
            raise SeregaError, "Invalid option preload_path: #{path.inspect}. Can be provided only when :preload option provided" unless preload

            serializer = opts[:serializer]
            raise SeregaError, "Invalid option preload_path: #{path.inspect}. Can be provided only when :serializer option provided" unless serializer
          end

          def check_required_when_many_allowed(path, allowed)
            return if path || (allowed.size < 2)

            raise SeregaError, "Option :preload_path must be provided. Possible values: #{allowed.inspect[1..-2]}"
          end

          def check_in_allowed(path, allowed)
            return if !path && allowed.size <= 1

            if multiple_preload_paths_provided?(path)
              check_many(path, allowed)
            else
              check_one(path, allowed)
            end
          end

          def check_one(path, allowed)
            formatted_path = Array(path).map(&:to_sym)
            return if allowed.include?(formatted_path)

            raise SeregaError,
              "Invalid preload_path (#{path.inspect}). " \
              "Can be one of #{allowed.inspect[1..-2]}"
          end

          def check_many(paths, allowed)
            paths.each { |path| check_one(path, allowed) }
          end

          # Check value is Array in Array
          def multiple_preload_paths_provided?(value)
            value.is_a?(Array) && value[0].is_a?(Array)
          end
        end
      end
    end
  end
end
