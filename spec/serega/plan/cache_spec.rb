# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::Cache do
  let(:address_serializer) do
    Class.new(Serega) do
      attribute :city
      attribute :zip
    end
  end

  let(:user_serializer) do
    address = address_serializer
    max_cached_plans = max_cached_plans_count
    check_initiate_params = check_initiate_params_config

    Class.new(Serega) do
      config.max_cached_plans_per_serializer_count = max_cached_plans
      config.check_initiate_params = check_initiate_params

      attribute :first_name
      attribute :last_name
      attribute :address, serializer: address
    end
  end

  let(:max_cached_plans_count) { 0 }
  let(:check_initiate_params_config) { true }

  # Plan of the modifiers, without validation
  def plan(modifiers)
    user_serializer.plan_cache.fetch(modifiers[:only], modifiers[:with], modifiers[:except], check_initiate_params: false)
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

    context "when the modifiers are a String" do
      before { allow(Serega::SeregaUtils::ParseStringModifiers).to receive(:parse).and_call_original }

      it "parses the String once" do
        result1 = plan(only: "address(city)")
        result2 = plan(only: "address(city)")

        expect(result1).to satisfy_attribute_names(address: {city: nil})
        expect(result2).to equal result1
        expect(Serega::SeregaUtils::ParseStringModifiers).to have_received(:parse).once
      end
    end

    context "when the cached modifiers have the hash of other modifiers" do
      let(:array_with_hash_zero) { Class.new(Array) { def hash = 0 } }
      let(:cached_only) { array_with_hash_zero[:first_name] }
      let(:other_only) { array_with_hash_zero[:last_name] }

      before { plan(only: cached_only) }

      it "builds the plan of the other modifiers" do
        expect(plan(only: other_only)).to satisfy_attribute_names(last_name: nil)
      end
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

  context "with another planner" do
    subject(:cache) { described_class.new(user_serializer, planner) }

    let(:planner) { class_double(Serega::SeregaPlan::ModifiersPlanner) }
    let(:params) { {include: "posts"} }
    let(:no_params) { {include: nil} }
    let(:params_plan) { default_plan(user_serializer) }
    let(:no_params_plan) { default_plan(user_serializer) }
    let(:empty) { false }

    before do
      allow(planner).to receive(:parse).with("posts", nil, nil).and_return(params)
      allow(planner).to receive(:parse).with(no_args).and_return(no_params)
      allow(planner).to receive(:empty?).and_return(empty)
      allow(planner).to receive(:plan).with(user_serializer, params).and_return(params_plan)
      allow(planner).to receive(:plan).with(user_serializer, no_params).and_return(no_params_plan)
      allow(planner).to receive(:validate)
    end

    it "builds the plan of the parameters with the planner" do
      expect(cache.fetch("posts", check_initiate_params: true)).to be params_plan

      expect(planner).to have_received(:parse).with("posts", nil, nil)
      expect(planner).to have_received(:empty?).with(params)
      expect(planner).to have_received(:validate).with(user_serializer, params)
      expect(planner).to have_received(:plan).with(user_serializer, params)
      expect(planner).not_to have_received(:parse).with(no_args)
      expect(planner).not_to have_received(:plan).with(user_serializer, no_params)
    end

    context "without check_initiate_params" do
      it "validates the parameters" do
        cache.fetch("posts")

        expect(planner).to have_received(:validate).with(user_serializer, params)
      end

      context "when config.check_initiate_params is false" do
        let(:check_initiate_params_config) { false }

        it "does not validate the parameters" do
          cache.fetch("posts")

          expect(planner).not_to have_received(:validate)
        end
      end
    end

    context "without parameters" do
      it "returns the plan the planner builds from no parameters" do
        expect(cache.fetch).to be no_params_plan

        expect(planner).to have_received(:parse).with(no_args)
        expect(planner).to have_received(:plan).with(user_serializer, no_params)
        expect(planner).not_to have_received(:empty?)
      end
    end

    context "when the planner finds the parameters empty" do
      let(:empty) { true }

      it "returns the plan the planner builds from no parameters" do
        expect(cache.fetch("posts", check_initiate_params: true)).to be no_params_plan

        expect(planner).not_to have_received(:validate)
        expect(planner).not_to have_received(:plan).with(user_serializer, params)
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
end
