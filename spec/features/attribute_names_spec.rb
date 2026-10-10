# frozen_string_literal: true

RSpec.describe Serega do
  describe "attributes named like BasicObject methods" do
    subject(:result) { user_serializer.to_h(user) }

    let(:user) { Struct.new(:title).new("Hello") }

    (BasicObject.public_instance_methods + BasicObject.private_instance_methods).sort.each do |name|
      context "with the :#{name} attribute" do
        let(:user_serializer) do
          Class.new(Serega) do
            config.check_attribute_name = false
            attribute name, method: :title
            attribute :title
            attribute :"page-title", method: :title
          end
        end

        it "serializes the attribute and the other attributes" do
          expect(result).to eq(name => "Hello", :title => "Hello", :"page-title" => "Hello")
        end
      end
    end
  end
end
