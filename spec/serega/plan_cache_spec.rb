# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanCache do
  let(:address_serializer) do
    Class.new(Serega) do
      attribute :city
      attribute :zip
    end
  end

  let(:user_serializer) do
    address = address_serializer
    max_cached_plans = max_cached_plans_count

    Class.new(Serega) do
      config.max_cached_plans_per_serializer_count = max_cached_plans

      attribute :first_name
      attribute :last_name
      attribute :address, serializer: address
    end
  end

  let(:max_cached_plans_count) { 0 }

  def plan(modifiers)
    user_serializer.plan_cache.fetch(modifiers[:only], modifiers[:with], modifiers[:except])
  end

  def satisfy_attribute_names(names)
    satisfy do |result|
      expect(result.points.count).to eq names.count

      names.each do |key, child_keys|
        point = result.points.find { |point| point.name == key }
        expect(point).not_to be_nil
        expect(point.child_plan).to satisfy_attribute_names(child_keys) if child_keys
      end
    end
  end

  context "without plan caching" do
    let(:max_cached_plans_count) { 0 }

    it "reuses one plan for missing and empty modifiers" do
      plan_without_modifiers = plan({})
      plan_with_empty_modifiers = plan(only: {}, with: {}, except: {})

      expect(plan_without_modifiers).to satisfy_attribute_names(first_name: nil, last_name: nil, address: {city: nil, zip: nil})
      expect(plan_with_empty_modifiers).to equal plan_without_modifiers
    end

    it "builds a new plan for each call with modifiers" do
      result1 = plan(only: {first_name: {}})
      result2 = plan(only: {first_name: {}})

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to satisfy_attribute_names(first_name: nil)
      expect(result1).not_to equal result2
    end
  end

  context "with plan caching" do
    let(:max_cached_plans_count) { 1 }

    it "reuses the cached plan for the same modifiers" do
      result1 = plan(only: {first_name: {}})
      result2 = plan(only: {first_name: {}})

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to equal result1
    end

    it "caches the plans of serializers built with other initiate options" do
      result1 = user_serializer.new(only: :first_name, check_initiate_params: false).plan
      result2 = user_serializer.new(only: :first_name, check_initiate_params: false).plan

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to equal result1
    end

    it "keeps the cached plan after the caller changes the modifiers hash" do
      only = {first_name: {}}
      result1 = plan(only: only)
      only[:last_name] = {}

      expect(plan(only: {first_name: {}})).to equal result1
    end

    it "keeps the cached plan after the caller changes the modifiers string" do
      only = +"first_name"
      result1 = user_serializer.new(only: only).plan
      only.replace("last_name")

      expect(user_serializer.new(only: "first_name").plan).to equal result1
    end

    it "shares the cached plan between calls with and without validation" do
      result1 = user_serializer.plan_cache.fetch({first_name: {}}, nil, nil, check_initiate_params: false)
      result2 = user_serializer.plan_cache.fetch({first_name: {}}, nil, nil, check_initiate_params: true)

      expect(result2).to equal result1
    end

    it "validates the modifiers of a plan that was cached without validation" do
      user_serializer.new(only: :email, check_initiate_params: false)

      expect { user_serializer.new(only: :email) }.to raise_error Serega::AttributeNotExist
    end

    it "validates the other initiate options of a cached plan" do
      user_serializer.new(only: :first_name)

      expect { user_serializer.new(only: :first_name, foo: 1) }.to raise_error Serega::SeregaError, /foo/
    end

    it "removes the oldest plan from a full cache" do
      result1 = plan(only: {first_name: {}})
      plan(only: {last_name: {}})
      result2 = plan(only: {first_name: {}})

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to satisfy_attribute_names(first_name: nil)
      expect(result2).not_to equal result1
    end

    context "when two serializers use the same modifiers" do
      before do
        allow(Serega::SeregaUtils::ToHash).to receive(:call).and_call_original
        allow(Serega::SeregaValidations::Initiate::CheckModifiers).to receive(:new).and_call_original
      end

      it "parses and validates the modifiers once" do
        2.times { user_serializer.new(only: [:first_name]) }

        expect(Serega::SeregaUtils::ToHash).to have_received(:call).with([:first_name]).once
        expect(Serega::SeregaValidations::Initiate::CheckModifiers).to have_received(:new).once
      end
    end
  end

  context "with room for two cached plans" do
    let(:max_cached_plans_count) { 2 }

    it "caches the same attribute names at different nesting levels separately" do
      nested = plan(only: {address: {city: {}}})
      flat = plan(only: {address: {}, city: {}})

      expect(nested).to satisfy_attribute_names(address: {city: nil})
      expect(flat).to satisfy_attribute_names(address: {city: nil, zip: nil})
    end
  end

  describe Serega::SeregaPlanCache::PerRactor, if: defined?(Ractor) do
    subject(:plan_cache) { serializer.plan_cache }

    let(:serializer) do
      Class.new(Serega) do
        attribute :name
        attribute :email
      end.freeze
    end

    it "returns the shared plan without modifiers" do
      plan = plan_cache.fetch(nil, nil, nil)

      expect(plan_cache.fetch(nil, nil, nil)).to be plan
    end

    it "builds the plan with modifiers once in a Ractor" do
      plan = plan_cache.fetch(:name, nil, nil)

      expect(plan.points.map(&:name)).to eq [:name]
      expect(plan_cache.fetch(:name, nil, nil)).to be plan
    end
  end
end
