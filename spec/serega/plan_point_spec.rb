# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanPoint do
  let(:base) { Class.new(Serega) }

  def point_for(serializer, name)
    serializer::SeregaPlan.new(nil, {}).points.find { |point| point.name == name }
  end

  describe "#preloads" do
    it "returns the attribute's declared preloads" do
      serializer = Class.new(base) { attribute :author, preload: :author }
      expect(point_for(serializer, :author).preloads).to eq :author
    end

    it "is nil when the attribute declares no preloads" do
      serializer = Class.new(base) { attribute :name }
      expect(point_for(serializer, :name).preloads).to be_nil
    end
  end

  describe "conditions" do
    let(:serializer) do
      opts = attribute_opts
      Class.new(base) { attribute :email, **opts }
    end

    let(:point) { point_for(serializer, :email) }
    let(:context) { {} }

    describe "#conditional?" do
      subject(:conditional) { point.conditional? }

      context "without conditions" do
        let(:attribute_opts) { {} }

        it "returns false" do
          expect(conditional).to be false
        end
      end

      %i[if unless if_value unless_value].each do |option|
        context "with the :#{option} condition" do
          let(:attribute_opts) { {option => :present?} }

          it "returns true" do
            expect(conditional).to be true
          end
        end
      end
    end

    describe "#satisfy_if_conditions?" do
      subject(:satisfied) { point.satisfy_if_conditions?(user, context) }

      let(:user_class) { Struct.new(:active, :admin) }
      let(:user) { user_class.new(active: true, admin: false) }

      context "without conditions" do
        let(:attribute_opts) { {} }

        it "returns true" do
          expect(satisfied).to be true
        end
      end

      context "with an :if condition" do
        let(:attribute_opts) { {if: :active} }

        it "returns true" do
          expect(satisfied).to be true
        end

        context "when the user fails the condition" do
          let(:user) { user_class.new(active: false, admin: false) }

          it "returns false" do
            expect(satisfied).to be false
          end
        end
      end

      context "with an :unless condition" do
        let(:attribute_opts) { {unless: :admin} }

        it "returns true" do
          expect(satisfied).to be true
        end

        context "when the user matches the condition" do
          let(:user) { user_class.new(active: true, admin: true) }

          it "returns false" do
            expect(satisfied).to be false
          end
        end
      end

      context "with :if and :unless conditions" do
        let(:attribute_opts) { {if: :active, unless: :admin} }

        it "returns true" do
          expect(satisfied).to be true
        end

        context "when the user passes :if and matches :unless" do
          let(:user) { user_class.new(active: true, admin: true) }

          it "returns false" do
            expect(satisfied).to be false
          end
        end
      end

      describe "condition parameters" do
        let(:context) { {show_emails: true} }

        context "with a condition without parameters" do
          let(:attribute_opts) { {if: -> { true }} }

          it "calls the condition without arguments" do
            expect(satisfied).to be true
          end
        end

        context "with a condition with the object parameter" do
          let(:attribute_opts) { {if: ->(user) { user.active }} }

          it "calls the condition with the object" do
            expect(satisfied).to be true
          end
        end

        context "with a condition with the object and context parameters" do
          let(:attribute_opts) { {if: ->(user, context) { user.active && context[:show_emails] }} }

          it "calls the condition with the object and the context" do
            expect(satisfied).to be true
          end
        end

        context "with a condition with the object parameter and the ctx keyword" do
          let(:attribute_opts) { {if: ->(user, ctx:) { user.active && ctx[:show_emails] }} }

          it "calls the condition with the object and the context keyword" do
            expect(satisfied).to be true
          end
        end

        context "with a condition with the object and context parameters and the ctx keyword" do
          let(:attribute_opts) { {if: ->(user, context, ctx:) { user.active && context[:show_emails] && ctx[:show_emails] }} }

          it "calls the condition with the object, the context and the context keyword" do
            expect(satisfied).to be true
          end
        end
      end
    end

    describe "#satisfy_if_value_conditions?" do
      subject(:satisfied) { point.satisfy_if_value_conditions?(email, context) }

      let(:email) { "ann@example.com" }

      context "without conditions" do
        let(:attribute_opts) { {} }

        it "returns true" do
          expect(satisfied).to be true
        end
      end

      context "with an :if_value condition" do
        let(:attribute_opts) { {if_value: ->(email) { email.end_with?("@example.com") }} }

        it "returns true" do
          expect(satisfied).to be true
        end

        context "when the value fails the condition" do
          let(:email) { "ann@test.com" }

          it "returns false" do
            expect(satisfied).to be false
          end
        end
      end

      context "with an :unless_value condition" do
        let(:attribute_opts) { {unless_value: :empty?} }

        it "returns true" do
          expect(satisfied).to be true
        end

        context "when the value matches the condition" do
          let(:email) { "" }

          it "returns false" do
            expect(satisfied).to be false
          end
        end
      end
    end
  end
end
