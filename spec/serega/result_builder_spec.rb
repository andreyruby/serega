# frozen_string_literal: true

RSpec.describe Serega::SeregaResultBuilder do
  subject(:result_builder) { described_class.new(serializer, mode, plan.points) }

  let(:serializer) do
    Class.new(Serega) do
      attribute :name
      attribute :email
    end
  end

  let(:plan) { default_plan(serializer) }
  let(:mode) { :hash }

  describe ".new" do
    let(:serializer) do
      attribute_name = name
      Class.new(Serega) do
        config.check_attribute_name = false
        attribute :title, const: "Hello"
        attribute attribute_name, const: "Ann"
      end
    end

    let(:name) { :author }
    let(:location) { serializer.attributes[name].location }

    it "defines #call and #call_one on the builder, not on its class" do
      expect(result_builder.singleton_methods).to include(:call, :call_one)
      expect(described_class.method_defined?(:call)).to be false
      expect(described_class.method_defined?(:call_one)).to be false
    end

    context "with an attribute named initialize in the :struct mode" do
      let(:name) { :initialize }
      let(:mode) { :struct }

      it "raises an error" do
        expect { result_builder }.to raise_error Serega::SeregaError,
          "Struct and Data can not have a member named initialize\n(when serializing the 'initialize' attribute in #{serializer}, #{location})"
      end
    end

    context "with an attribute named initialize in the :data mode" do
      let(:name) { :initialize }
      let(:mode) { :data }

      it "raises an error" do
        expect { result_builder }.to raise_error Serega::SeregaError,
          "Struct and Data can not have a member named initialize\n(when serializing the 'initialize' attribute in #{serializer}, #{location})"
      end
    end

    context "with an attribute name ending with = in the :data mode" do
      let(:name) { :name= }
      let(:mode) { :data }

      it "raises an error with the reason from Ruby" do
        expect { result_builder }.to raise_error Serega::SeregaError,
          "invalid data member: name=\n(when serializing the 'name=' attribute in #{serializer}, #{location})"
      end
    end

    context "with an attribute name ending with = in the :struct mode", if: RUBY_ENGINE == "ruby" do
      let(:name) { :name= }
      let(:mode) { :struct }

      it "raises an error with the reason from Ruby" do
        expect { result_builder }.to raise_error Serega::SeregaError,
          "invalid struct member: name=\n(when serializing the 'name=' attribute in #{serializer}, #{location})"
      end
    end

    context "with an operator attribute name in the :data mode" do
      let(:name) { :+ }
      let(:mode) { :data }

      it "builds Data objects" do
        expect(result_builder.call([nil], {}, nil, nil).map(&:to_h)).to eq [{title: "Hello", "+": "Ann"}]
      end
    end
  end

  describe "#call" do
    let(:user) { Struct.new(:name, :email).new("Ann", "ann@example.com") }

    it "is generated code with a file name without a source" do
      path, line = result_builder.method(:call).source_location

      expect(path).to eq "(serega generated code)"
      expect(line).to eq 1
    end

    it "builds a Hash per object" do
      expect(result_builder.call([user], {}, nil, nil)).to eq [{name: "Ann", email: "ann@example.com"}]
    end

    context "with the :struct mode" do
      let(:mode) { :struct }

      it "builds a Struct per object" do
        struct_class = serializer.struct_class_for(%i[name email])

        expect(result_builder.call([user], {}, nil, nil)).to eq [struct_class.new("Ann", "ann@example.com")]
      end
    end

    context "with the :data mode" do
      let(:mode) { :data }

      it "builds a Data object per object" do
        data_class = serializer.data_class_for(%i[name email])

        expect(result_builder.call([user], {}, nil, nil)).to eq [data_class.new("Ann", "ann@example.com")]
      end
    end

    context "with a relation" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name
          attribute :posts, serializer: Class.new(Serega)
        end
      end

      it "reads relation values from the serialized child objects" do
        relations = {plan.points[1] => [["POST"]]}

        expect(result_builder.call([user], {}, nil, relations)).to eq [{name: "Ann", posts: ["POST"]}]
      end
    end

    context "with a batch attribute" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name, batch: {use: proc { |ids| ids }, id: :email}
        end
      end

      it "reads values from the loaded batches" do
        expect(result_builder.call([user], {}, [{name: {"ann@example.com" => "Batch Ann"}}], nil)).to eq [{name: "Batch Ann"}]
      end
    end

    context "with a not plain method name" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name, method: :"full-name"
        end
      end

      let(:user) { double("full-name": "Ann Smith") }

      it "calls the method" do
        expect(result_builder.call([user], {}, nil, nil)).to eq [{name: "Ann Smith"}]
      end
    end

    context "when an attribute raises an error" do
      let(:user) { Struct.new(:name).new("Ann") }

      it "adds the attribute name to the error message" do
        expect { result_builder.call([user], {}, nil, nil) }
          .to raise_error(NoMethodError, /when serializing the 'email' attribute/)
      end

      it "puts the attribute line above the generated code line in the backtrace" do
        location = serializer.attributes[:email].location

        expect { result_builder.call([user], {}, nil, nil) }.to raise_error(NoMethodError) do |error|
          expect(error.backtrace[0]).to eq "#{location}:in 'attribute :email of #{serializer}'"
          expect(error.backtrace[1]).to start_with "(serega generated code):"
        end
      end
    end
  end

  describe "#call_one" do
    let(:user) { Struct.new(:name, :email).new("Ann", "ann@example.com") }

    it "builds the Hash of the object" do
      expect(result_builder.call_one(user, {})).to eq(name: "Ann", email: "ann@example.com")
    end

    context "with the :data mode" do
      let(:mode) { :data }

      it "builds the Data object of the object" do
        data_class = serializer.data_class_for(%i[name email])

        expect(result_builder.call_one(user, {})).to eq data_class.new("Ann", "ann@example.com")
      end
    end

    context "with a relation" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :posts, serializer: Class.new(Serega)
        end
      end

      it "is not defined" do
        expect(result_builder).not_to respond_to(:call_one)
      end
    end

    context "with a batch attribute" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name, batch: {use: proc { |ids| ids }, id: :email}
        end
      end

      it "is not defined" do
        expect(result_builder).not_to respond_to(:call_one)
      end
    end
  end
end
