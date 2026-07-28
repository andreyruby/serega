# frozen_string_literal: true

class Serega
  #
  # Helpers
  #
  # @private
  module SeregaHelpers
    #
    # Stores link to current serializer class
    #
    # @private
    module SerializerClassHelper
      # Shows serializer class current class is namespaced under
      # @return [Class<Serega>] Serializer class that current class is namespaced under.
      attr_accessor :serializer_class
    end
  end
end
