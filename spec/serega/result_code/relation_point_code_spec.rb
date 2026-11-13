# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode::RelationPointCode do
  let(:point_code) { described_class.new(point, 1) }
  let(:point) { default_plan(serializer).points.first }

  let(:serializer) do
    post_serializer = Class.new(Serega) { attribute :title }
    Class.new(Serega) { attribute :posts, serializer: post_serializer, many: true }
  end

  describe "#variables" do
    it "returns the code that reads the relation values" do
      expect(point_code.variables).to eq ["relation_values_1 = relations[@points[1]]"]
    end
  end

  describe "#assign_value" do
    it "returns the code that assigns the relation value of the source" do
      expect(point_code.assign_value).to eq "value_1 = relation_values_1[source_index]"
    end
  end

  describe "#call_one?" do
    it "returns false" do
      expect(point_code.call_one?).to be false
    end
  end

  describe "#collect" do
    subject(:code) { point_code.collect }

    it "returns the loop that collects the child sources and the pulls" do
      expect(code).to eq <<~RUBY.chomp
        child_sources_1 = []
        collection_classes_1 = @points[1].collection_classes
        pulls_1 = Array.new(size)
        source_index = 0
        while source_index < size
          source = sources[source_index]
          value_1 =
            begin
              (value = source.posts).nil? ? SeregaAttributeValues::DEFAULTS[:posts] : value
            rescue => error
              Serega::SeregaUtils::SerializedAttributeError.call(error, @points[1])
            end
          pulls_1[source_index] =
            if value_1.nil?
              nil
            elsif value_1.instance_of?(Array) || Serega::SeregaUtils::CollectionDetector.call(value_1, collection_classes_1)
              collection = value_1.to_a
              child_sources_1.concat(collection)
              collection.size
            else
              child_sources_1 << value_1
              1
            end
          source_index += 1
        end
      RUBY
    end

    context "with a relation to one object" do
      let(:serializer) do
        post_serializer = Class.new(Serega) { attribute :title }
        Class.new(Serega) { attribute :post, serializer: post_serializer, many: false }
      end

      it "returns the loop that adds each relation source as one source" do
        expect(code).to include <<~RUBY.chomp
          pulls_1[source_index] =
              if value_1.nil?
                nil
              else
                child_sources_1 << value_1
                Serega::SeregaEngine::Pulls::SINGLE_SOURCE
              end
        RUBY
      end
    end

    context "with a relation without the :many option" do
      let(:serializer) do
        post_serializer = Class.new(Serega) { attribute :title }
        Class.new(Serega) { attribute :post, serializer: post_serializer }
      end

      it "returns the loop that finds collections and adds other relation sources as one source" do
        expect(code)
          .to include("elsif value_1.instance_of?(Array) || Serega::SeregaUtils::CollectionDetector.call(value_1, collection_classes_1)")
          .and include("child_sources_1 << value_1\n      Serega::SeregaEngine::Pulls::SINGLE_SOURCE")
      end
    end

    context "with a conditional relation" do
      let(:serializer) do
        post_serializer = Class.new(Serega) { attribute :title }
        Class.new(Serega) { attribute :posts, serializer: post_serializer, many: true, if: :active? }
      end

      it "returns the loop that keeps SKIP as the pull" do
        expect(code).to include <<~RUBY.chomp
          pulls_1[source_index] =
              if Serega::SeregaEngine::SKIP.equal?(value_1)
                value_1
              elsif value_1.nil?
        RUBY
      end
    end
  end
end
