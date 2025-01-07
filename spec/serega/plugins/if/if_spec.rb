# frozen_string_literal: true

load_plugin_code :if

RSpec.describe Serega::SeregaPlugins::If do
  let(:serializer) { Class.new(Serega) }

  describe "loading" do
    it "allows additional attribute options" do
      serializer.plugin :if
      attribute_keys = serializer.config.attribute_keys
      expect(attribute_keys).to include :if
      expect(attribute_keys).to include :if_value
      expect(attribute_keys).to include :unless
      expect(attribute_keys).to include :unless_value
    end
  end

  describe "validations" do
    it "checks new options" do
      expect { serializer.attribute :foo, if: true }.to raise_error Serega::SeregaError
      expect { serializer.attribute :foo, unless: true }.to raise_error Serega::SeregaError
      expect { serializer.attribute :foo, if_value: true }.to raise_error Serega::SeregaError
      expect { serializer.attribute :foo, unless_value: true }.to raise_error Serega::SeregaError
    end
  end

  describe "SeregaPlanPoint methods" do
    before { serializer.plugin :if }

    def point(attribute)
      attribute.class.serializer_class::SeregaPlanPoint.new("plan", attribute, nil)
    end

    describe "#satisfy_if_conditions?" do
      let(:ctx) { {} }

      it "works when no conditions" do
        attribute = serializer.attribute :next
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be true
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when :if is a Symbol" do
        attribute = serializer.attribute :next, if: :even?
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when :if is a Proc" do
        attribute = serializer.attribute :next, if: proc { |obj| obj.even? }
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when :if is a Proc with ctx keyword" do
        attribute = serializer.attribute :next, if: lambda { |_obj, ctx:| ctx[:allowed] }
        point = point(attribute)
        ctx = {allowed: true}
        expect(point.satisfy_if_conditions?(1, ctx)).to be true
      end

      it "works when :if is a Proc with no params" do
        attribute = serializer.attribute :next, if: lambda { false }
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
      end

      it "works when :if is #callable" do
        callable = Class.new {
          def self.call(obj, ctx)
            obj.even?
          end
        }
        attribute = serializer.attribute :next, if: callable
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when :unless is a Symbol" do
        attribute = serializer.attribute :next, unless: :odd?
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when :unless is a Proc" do
        attribute = serializer.attribute :next, unless: proc { |obj| obj.odd? }
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when :unless is #callable" do
        callable = Class.new {
          def self.call(obj, ctx)
            obj.odd?
          end
        }
        attribute = serializer.attribute :next, unless: callable
        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be true
      end

      it "works when both :if and :unless provided" do
        attribute = serializer.attribute :next,
          if: proc { |obj| obj > 1 }, #  allowed 2..
          unless: proc { |obj| obj < 3 } # allowed 3..

        point = point(attribute)
        expect(point.satisfy_if_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_conditions?(2, ctx)).to be false
        expect(point.satisfy_if_conditions?(3, ctx)).to be true
      end
    end

    describe "#satisfy_if_value_conditions?" do
      let(:ctx) { {} }

      it "works when no conditions" do
        attribute = serializer.attribute :next
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be true
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when :if_value is a Symbol" do
        attribute = serializer.attribute :next, if_value: :even?
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when :if_value is a Proc" do
        attribute = serializer.attribute :next, if_value: proc { |obj| obj.even? }
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when :if_value is #callable" do
        callable = Class.new {
          def self.call(obj, ctx)
            obj.even?
          end
        }
        attribute = serializer.attribute :next, if_value: callable
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when :unless_value is a Symbol" do
        attribute = serializer.attribute :next, unless_value: :odd?
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when :unless_value is a Proc" do
        attribute = serializer.attribute :next, unless_value: proc { |obj| obj.odd? }
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when :unless_value is #callable" do
        callable = Class.new {
          def self.call(obj, ctx)
            obj.odd?
          end
        }
        attribute = serializer.attribute :next, unless_value: callable
        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be true
      end

      it "works when both :if_value and :unless_value provided" do
        attribute = serializer.attribute :next,
          if_value: proc { |obj| obj > 1 }, #  allowed 2..
          unless_value: proc { |obj| obj < 3 } # allowed 3..

        point = point(attribute)
        expect(point.satisfy_if_value_conditions?(1, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(2, ctx)).to be false
        expect(point.satisfy_if_value_conditions?(3, ctx)).to be true
      end
    end
  end

  describe "serializing" do
    it "hides attributes when :if condition matches" do
      serializer.plugin :if

      serializer.attribute(:foo, const: "foo")
      serializer.attribute(:bar1, const: 1, if: proc { |obj, ctx| obj != 1 })
      serializer.attribute(:bar2, const: 2, if: proc { |obj, ctx| obj == 1 })
      serializer.attribute(:bar3, const: 3, if: proc { |obj, ctx| ctx[:keep] == false })
      serializer.attribute(:bar4, const: 4, if: proc { |obj, ctx| ctx[:keep] == true })

      expect(serializer.new.to_h(1, context: {keep: true})).to eq(
        foo: "foo", bar2: 2, bar4: 4
      )
    end

    it "hides attributes when :if_value condition matches" do
      serializer.plugin :if

      serializer.attribute(:foo, const: "foo")
      serializer.attribute(:bar1, const: 1, if_value: proc { |val, ctx| val != 1 })
      serializer.attribute(:bar2, const: 2, if_value: proc { |val, ctx| val != 1 })
      serializer.attribute(:bar3, const: 3, if_value: proc { |val, ctx| ctx[:keep] == false })
      serializer.attribute(:bar4, const: 4, if_value: proc { |val, ctx| ctx[:keep] == true })

      expect(serializer.new.to_h(1, context: {keep: true})).to eq(
        foo: "foo", bar2: 2, bar4: 4
      )
    end

    context "with batch attribute" do
      context "when skipping regular attribute" do
        let(:user_serializer) do
          Class.new(Serega) do
            plugin :if

            attribute :id
            attribute :online_time,
              if: proc { |obj| obj.id != 1 },
              batch: proc { |_users| {1 => 10, 2 => 20} }
          end
        end

        let(:users) do
          [
            double(id: 1),
            double(id: 2)
          ]
        end

        it "returns correct response" do
          result = user_serializer.to_h(users)
          expect(result).to eq(
            [
              {id: 1}, # no online_time for user with id 1
              {id: 2, online_time: 20}
            ]
          )
        end
      end

      context "when skipping relation attribute and nested attributes" do
        let(:status_serializer) do
          _status1, _status2, status3, status4, _status5 = statuses
          Class.new(Serega) do
            plugin :if
            attribute :text,
              unless: proc { |obj| obj == status4 }, # should skip status4 text
              unless_value: proc { |val| val == status3.text } # should skip status3 text
          end
        end

        let(:user_serializer) do
          status1, status2, status3, status4, status5 = statuses
          child_serializer = status_serializer
          Class.new(Serega) do
            plugin :if

            attribute :id
            attribute :status,
              serializer: child_serializer,
              if: proc { |obj| obj.id != 1 }, # should skip status for user1
              batch: proc { |_keys|
                {
                  1 => status1,
                  2 => status2,
                  3 => status3,
                  4 => status4,
                  5 => status5
                }
              }
          end
        end

        let(:users) do
          [
            double(id: 1),
            double(id: 2),
            double(id: 3),
            double(id: 4),
            double(id: 5)
          ]
        end

        let(:status1) { double(id: 1, text: "TEXT1") }
        let(:status2) { double(id: 2, text: "TEXT2") }
        let(:status3) { double(id: 3, text: "TEXT3") }
        let(:status4) { double(id: 4, text: "TEXT4") }
        let(:status5) { double(id: 5, text: "TEXT5") }
        let(:statuses) { [status1, status2, status3, status4, status5] }

        it "returns array with relations" do
          result = user_serializer.to_h(users)
          expect(result).to eq(
            [
              {id: 1}, # skipped status
              {id: 2, status: {text: "TEXT2"}},
              {id: 3, status: {}}, # skipped status text
              {id: 4, status: {}}, # skipped status text
              {id: 5, status: {text: "TEXT5"}}
            ]
          )
        end
      end
    end
  end
end
