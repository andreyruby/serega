# frozen_string_literal: true

RSpec.describe Serega::SeregaConditions do
  let(:serializer) do
    opts = attribute_opts
    Class.new(Serega) { attribute :email, **opts }
  end

  let(:conditions) { serializer.attributes[:email].conditions }
  let(:context) { {} }

  describe "#satisfy?" do
    subject(:satisfied) { conditions.satisfy?(user, context) }

    let(:user_class) { Struct.new(:active, :admin) }
    let(:user) { user_class.new(active: true, admin: false) }

    context "with value conditions only" do
      let(:attribute_opts) { {if_value: :present?} }

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

    context "when a condition raises" do
      let(:attribute_opts) { {unless: proc { raise "boom in condition" }} }

      it "adds the condition, the attribute and its location to the error message" do
        location = serializer.attributes[:email].location

        expect { satisfied }
          .to raise_error RuntimeError, "boom in condition\n(when checking the :unless condition of the 'email' attribute in #{serializer}, #{location})"
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

  describe "#satisfy_value?" do
    subject(:satisfied) { conditions.satisfy_value?(email, context) }

    let(:email) { "ann@example.com" }

    context "with object conditions only" do
      let(:attribute_opts) { {if: :active} }

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
