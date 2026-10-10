# frozen_string_literal: true

class Serega
  #
  # Builds the serialized objects (Hash, Struct or Data) of one plan in one
  # serialization mode.
  #
  # The builder gets the code of its `#call` method from SeregaResultCode.
  # The method builds the serialized objects of a source group in one loop.
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
        classes = @data_classes
        classes = SeregaUtils::RactorLocal.fetch(self, :data_classes) { {} } if classes.frozen?
        classes[point_names] ||= Data.define(*point_names)
      end

      #
      # Returns (and caches) the Struct class for the given set of field names.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Struct members
      # @return [Class] Subclass of Struct
      #
      def struct_class_for(point_names)
        classes = @struct_classes
        classes = SeregaUtils::RactorLocal.fetch(self, :struct_classes) { {} } if classes.frozen?
        classes[point_names] ||= Struct.new(*point_names)
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
      #   call(sources, context, batches, relations) -> Array<Hash, Struct, Data>
      #
      # - `batches` holds the loaded batches per point, or nil.
      # - `relations` holds the relation values of all sources per relation
      #   point, or nil.
      #
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param points [Array<SeregaPlanPoint>] Serialized plan points
      #
      def initialize(mode, points)
        @mode = mode
        @points = points
        @result_class = result_class
        serializer_class = self.class.serializer_class
        @attribute_values = serializer_class::SeregaAttributeValues.new
        call_code = serializer_class::SeregaResultCode.new(mode, points).to_s
        singleton_class.class_eval(call_code, "(serega generated code)", 1)
      end

      private

      def result_class
        return if mode == :hash

        initialize_point = @points.find { |point| point.name == :initialize }
        raise_member_error("Struct and Data can not have a member named initialize", initialize_point) if initialize_point

        member_class(@points.map(&:name))
      end

      # Returns the Struct or Data class with the members. Raises a
      # SeregaError for an attribute name that Ruby can not make a member.
      def member_class(names)
        (mode == :struct) ? self.class.struct_class_for(names) : self.class.data_class_for(names)
      rescue ArgumentError, NameError => error
        point = @points.find { |point| !member_name?(point.name) }
        raise_member_error(error.message, point)
      end

      def member_name?(name)
        (mode == :struct) ? Struct.new(name) : Data.define(name)
        true
      rescue ArgumentError, NameError
        false
      end

      def raise_member_error(message, point)
        SeregaUtils::SerializedAttributeError.call(SeregaError.new(message), point)
      end
    end

    extend ClassMethods
    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
