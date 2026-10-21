# frozen_string_literal: true

class Serega
  #
  # Helpers
  #
  module SeregaHelpers # :nodoc:
    #
    # Stores link to current serializer class
    #
    module SerializerClassHelper # :nodoc:
      # Shows serializer class current class is namespaced under
      # @return [Class<Serega>] Serializer class that current class is namespaced under.
      attr_accessor :serializer_class
    end
  end
end
