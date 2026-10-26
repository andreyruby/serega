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
  class SeregaResultBuilder # :nodoc:
    # Serialization mode
    attr_reader :mode

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
    def initialize(serializer_class, mode, points)
      @mode = mode
      @points = points
      @result_class = result_class(serializer_class)
      # The generated code reads the `:const`, `:default` and formatter values from its constants
      singleton_class.const_set(:SeregaAttributeValues, serializer_class::SeregaAttributeValues)
      singleton_class.class_eval(SeregaResultCode.new(mode, points).to_s, SeregaUtils::SerializedAttributeError::GENERATED_CODE_FILE, 1)
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
