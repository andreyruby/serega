# frozen_string_literal: true

class Serega
  #
  # Builds serialization results of one plan in one serialization mode:
  # empty result containers filled in place during serialization.
  #
  # @private
  class SeregaResultBuilder
    @data_classes = {}
    @struct_classes = {}

    #
    # SeregaResultBuilder class methods
    #
    # @private
    module ClassMethods
      #
      # Returns (and caches) the Data class for the given set of field names.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Data members
      # @return [Class] Subclass of Data
      #
      def data_class_for(point_names)
        @data_classes[point_names] ||= Data.define(*point_names)
      end

      #
      # Returns (and caches) the Struct class for the given set of field names.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Struct members
      # @return [Class] Subclass of Struct
      #
      def struct_class_for(point_names)
        @struct_classes[point_names] ||= Struct.new(*point_names)
      end

      private

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@data_classes, {})
        subclass.instance_variable_set(:@struct_classes, {})
      end
    end

    #
    # SeregaResultBuilder instance methods
    #
    # @private
    module InstanceMethods
      # Serialization mode
      # @return [Symbol] :hash, :data or :struct
      attr_reader :mode

      #
      # Instantiates new result builder
      #
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param points [Array<SeregaPlanPoint>] Serialized plan points
      #
      def initialize(mode, points)
        @mode = mode
        @point_names = points.map(&:name).freeze
        @data_class = nil
        @struct_class = nil
      end

      # Returns the Data class whose members match the serialized fields.
      #
      # @return [Class] Subclass of Data
      #
      def data_class
        @data_class ||= self.class.data_class_for(@point_names)
      end

      # Returns the Struct class whose members match the serialized fields.
      #
      # @return [Class] Subclass of Struct
      #
      def struct_class
        @struct_class ||= self.class.struct_class_for(@point_names)
      end

      #
      # empty result containers filled in place during serialization.
      #
      # Patched in:
      # - plugin :if (builds :data containers with nil values of all attributes)
      #
      # @param count [Integer] Number of containers
      #
      # @return [Array<Hash, Struct>] Empty containers
      #
      def build_containers(count)
        case mode
        when :struct
          struct_class = self.struct_class
          Array.new(count) { struct_class.new }
        else Array.new(count) { {} } # :hash, :data
        end
      end
    end

    extend ClassMethods
    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
