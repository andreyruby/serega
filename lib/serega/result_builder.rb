# frozen_string_literal: true

class Serega
  #
  # Builds the serialized objects (Hash, Struct or Data) of one plan in one
  # serialization mode.
  #
  # The builder gets the code of its `#call` method from SeregaResultCode.
  # The method builds the serialized objects of an object group in one loop.
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
      # Instantiates new result builder and generates its `#call` method:
      #
      #   call(objects, context, batches, relations) -> Array<Hash, Struct, Data>
      #
      # - `batches` holds the loaded batches per point, or nil.
      # - `relations` holds the relation values of all objects per relation
      #   point, or nil.
      #
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param points [Array<SeregaPlanPoint>] Serialized plan points
      #
      def initialize(mode, points)
        @mode = mode
        @points = points
        @result_class = result_class
        call_code = self.class.serializer_class::SeregaResultCode.new(mode, points).to_s
        singleton_class.class_eval(call_code, __FILE__, __LINE__)
      end

      private

      def result_class
        case mode
        when :struct then self.class.struct_class_for(@points.map(&:name))
        when :data then self.class.data_class_for(@points.map(&:name))
        end
      end
    end

    extend ClassMethods
    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
