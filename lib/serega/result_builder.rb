# frozen_string_literal: true

class Serega
  #
  # Builds the serialized objects (Hash, Struct or Data) of one plan in one
  # serialization mode.
  #
  # The builder gets the code of its `#call` and `#call_one` methods from
  # SeregaResultCode. `#call` builds the serialized objects of a source group
  # in one loop.
  #
  # @private
  class SeregaResultBuilder
    class << self
      #
      # Makes a result builder and generates its methods:
      #
      #   call(sources, context, batches, relations) -> Array<Hash, Struct, Data>
      #
      # - `batches` holds the loaded batches per point, or nil.
      # - `relations` holds the relation values of all sources per relation
      #   point, or nil.
      #
      # Points without relations and batch loaders get a `#call_one` method
      # too, which builds the serialized object of one source:
      #
      #   call_one(source, context) -> Hash, Struct, Data
      #
      # The builder is the instance of a new subclass, as YJIT calls the
      # methods of an object with a singleton class slower. The subclass gets
      # the methods before the instance is made: YJIT ran `#call` of a builder
      # made first slower.
      #
      # @param (see #initialize)
      #
      # @return [SeregaResultBuilder] Result builder
      #
      def build(serializer_class, mode, points)
        builder_class = Class.new(self)
        # The generated code reads the `:const`, `:default` and formatter values from its constants
        builder_class.const_set(:SeregaAttributeValues, serializer_class::SeregaAttributeValues)
        builder_class.class_eval(SeregaResultCode.new(mode, points).to_s, SeregaUtils::SerializedAttributeError::GENERATED_CODE_FILE, 1)
        builder_class.new(serializer_class, mode, points)
      end
    end

    # Serialization mode
    # @return [Symbol] :hash, :data or :struct
    attr_reader :mode

    #
    # Instantiates new result builder
    #
    # @param serializer_class [Class<Serega>] Serializer of the points
    # @param mode [Symbol] Serialization mode - :hash, :data or :struct
    # @param points [Array<SeregaPlanPoint>] Serialized plan points
    #
    def initialize(serializer_class, mode, points)
      @mode = mode
      @points = points
      @result_class = result_class(serializer_class)
    end

    private

    def result_class(serializer_class)
      return if mode == :hash

      initialize_point = @points.find { |point| point.name == :initialize }
      raise_member_error("Struct and Data can not have a member named initialize", initialize_point) if initialize_point

      member_class(serializer_class, @points.map(&:name))
    end

    # Returns the Struct or Data class with the members. Raises a
    # SeregaError for an attribute name that Ruby can not make a member.
    def member_class(serializer_class, names)
      (mode == :struct) ? serializer_class.struct_class_for(names) : serializer_class.data_class_for(names)
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
end
