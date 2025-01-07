# frozen_string_literal: true

class Serega
  module SeregaValidations
    #
    # Batch loader parameters validators
    #
    class CheckBatchLoaderParams
      #
      # batch_loader parameters validation instance methods
      #
      module InstanceMethods
        # @return [Symbol] validated batch_loader name
        attr_reader :name

        # @return [nil, #call] validated batch_loader value or block
        attr_reader :batch_loader

        # Instantiates batch loader params checker
        # @param name [Symbol, String] Batch loader name
        # @param batch_loader [Proc, #call] Batch loader
        def initialize(name, batch_loader)
          @name = name
          @batch_loader = batch_loader
        end

        #
        # Checks batch loader parameters
        #
        # @raise [SeregaError] SeregaError that batch loader has invalid arguments
        #
        # @return [void]
        #
        def validate
          check_name
          check_loader
        end

        private

        def check_name
          raise SeregaError, name_type_error if !name.is_a?(Symbol) && !name.is_a?(String)
        end

        def check_loader
          check_batch_loader_type
          check_batch_loader_args
        end

        def check_batch_loader_type
          raise SeregaError, type_error if !batch_loader.is_a?(Proc) && !batch_loader.respond_to?(:call)
        end

        def check_batch_loader_args
          signature = SeregaUtils::MethodSignature.call(batch_loader, pos_limit: 2, keyword_args: [:ctx])
          raise SeregaError, arguments_error unless %w[1 2 1_ctx].include?(signature)
        end

        def name_type_error
          "Batch loader name must be a Symbol or String"
        end

        def type_error
          "Batch loader value must be a Proc or respond to #call"
        end

        def arguments_error
          <<~ERR.strip
            Batch loader arguments should have one of this signatures:
            - (objects)       # one argument
            - (objects, :ctx) # one argument and one :ctx keyword argument
          ERR
        end
      end

      include InstanceMethods
      extend Serega::SeregaHelpers::SerializerClassHelper
    end
  end
end
