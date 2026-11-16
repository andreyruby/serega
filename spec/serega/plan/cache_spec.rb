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

    Class.new(Serega) do
      config.max_cached_plans_per_serializer_count = max_cached_plans

      attribute :first_name
      attribute :last_name
      attribute :address, serializer: address
    end
  end

  let(:max_cached_plans_count) { 0 }

  # Plan of the selection
  def plan(selection)
    user_serializer.plan_cache.fetch(selection[:only], selection[:with], selection[:except], selection[:preset])
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

    it "reuses one plan for missing and empty selection" do
      plan_without_selection = plan({})
      plan_with_empty_selection = plan(only: {}, with: {}, except: {})

      expect(plan_without_selection).to satisfy_attribute_names(first_name: nil, last_name: nil, address: {city: nil, zip: nil})
      expect(plan_with_empty_selection).to equal plan_without_selection
    end

    it "builds a new plan for each call with selection" do
      result1 = plan(only: {first_name: {}})
      result2 = plan(only: {first_name: {}})

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to satisfy_attribute_names(first_name: nil)
      expect(result1).not_to equal result2
    end
  end

  context "with plan caching" do
    let(:max_cached_plans_count) { 1 }

    it "reuses the cached plan for the same selection" do
      result1 = plan(only: {first_name: {}})
      result2 = plan(only: {first_name: {}})

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to equal result1
    end

    it "caches the plans of serializers built with other options" do
      result1 = user_serializer.new(only: :first_name).plan
      result2 = user_serializer.new(only: :first_name).plan

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to equal result1
    end

    it "keeps the cached plan after the caller changes the selection hash" do
      only = {first_name: {}}
      result1 = plan(only: only)
      only[:last_name] = {}

      expect(plan(only: {first_name: {}})).to equal result1
    end

    it "keeps the cached plan after the caller changes the selection string" do
      only = +"first_name"
      result1 = user_serializer.new(only: only).plan
      only.replace("last_name")

      expect(user_serializer.new(only: "first_name").plan).to equal result1
    end

    context "when the selection are a String" do
      before { allow(Serega::SeregaUtils::ParseStringSelection).to receive(:parse).and_call_original }

      it "parses the String once" do
        result1 = plan(only: "address(city)")
        result2 = plan(only: "address(city)")

        expect(result1).to satisfy_attribute_names(address: {city: nil})
        expect(result2).to equal result1
        expect(Serega::SeregaUtils::ParseStringSelection).to have_received(:parse).once
      end
    end

    context "when the cached selection have the hash of other selection" do
      let(:array_with_hash_zero) { Class.new(Array) { def hash = 0 } }
      let(:cached_only) { array_with_hash_zero[:first_name] }
      let(:other_only) { array_with_hash_zero[:last_name] }

      before { plan(only: cached_only) }

      it "builds the plan of the other selection" do
        expect(plan(only: other_only)).to satisfy_attribute_names(last_name: nil)
      end
    end

    it "removes the oldest plan from a full cache" do
      result1 = plan(only: {first_name: {}})
      plan(only: {last_name: {}})
      result2 = plan(only: {first_name: {}})

      expect(result1).to satisfy_attribute_names(first_name: nil)
      expect(result2).to satisfy_attribute_names(first_name: nil)
      expect(result2).not_to equal result1
    end

    context "when two serializers use the same selection" do
      before do
        allow(Serega::SeregaUtils::ToHash).to receive(:call).and_call_original
        allow(Serega::SeregaValidations::CheckSelection).to receive(:new).and_call_original
      end

      it "parses and validates the selection once" do
        2.times { user_serializer.new(only: [:first_name]) }

        expect(Serega::SeregaUtils::ToHash).to have_received(:call).with([:first_name]).once
        expect(Serega::SeregaValidations::CheckSelection).to have_received(:new).once
      end
    end
  end

  context "with another planner" do
    subject(:cache) { described_class.new(user_serializer, planner) }

    let(:planner) { class_double(Serega::SeregaPlan::SelectionPlanner) }
    let(:params) { {include: "posts"} }
    let(:no_params) { {include: nil} }
    let(:params_plan) { default_plan(user_serializer) }
    let(:no_params_plan) { default_plan(user_serializer) }
    let(:empty) { false }

    before do
      allow(planner).to receive(:parse).with(user_serializer, "posts", nil, nil, nil).and_return(params)
      allow(planner).to receive(:parse).with(user_serializer).and_return(no_params)
      allow(planner).to receive(:empty?).and_return(empty)
      allow(planner).to receive(:plan).with(user_serializer, params).and_return(params_plan)
      allow(planner).to receive(:plan).with(user_serializer, no_params).and_return(no_params_plan)
      allow(planner).to receive(:validate)
    end

    it "builds the plan of the parameters with the planner" do
      expect(cache.fetch("posts")).to be params_plan

      expect(planner).to have_received(:parse).with(user_serializer, "posts", nil, nil, nil)
      expect(planner).to have_received(:empty?).with(params)
      expect(planner).to have_received(:validate).with(user_serializer, params)
      expect(planner).to have_received(:plan).with(user_serializer, params)
      expect(planner).not_to have_received(:parse).with(user_serializer)
      expect(planner).not_to have_received(:plan).with(user_serializer, no_params)
    end

    context "without parameters" do
      it "returns the plan the planner builds from no parameters" do
        expect(cache.fetch).to be no_params_plan

        expect(planner).to have_received(:parse).with(user_serializer)
        expect(planner).to have_received(:plan).with(user_serializer, no_params)
        expect(planner).not_to have_received(:empty?)
      end
    end

    context "when the planner finds the parameters empty" do
      let(:empty) { true }

      it "returns the plan the planner builds from no parameters" do
        expect(cache.fetch("posts")).to be no_params_plan

        expect(planner).not_to have_received(:validate)
        expect(planner).not_to have_received(:plan).with(user_serializer, params)
      end
    end
  end

  context "with room for two cached plans" do
    let(:max_cached_plans_count) { 2 }
    let(:user_serializer) { Class.new(super()) { attribute :city } }

    it "caches the same attribute names at different nesting levels separately" do
      nested = plan(only: {address: {city: {}}})
      flat = plan(only: {address: {}, city: {}})

      expect(nested).to satisfy_attribute_names(address: {city: nil})
      expect(flat).to satisfy_attribute_names(address: {city: nil, zip: nil}, city: nil)
    end
  end

  context "with room for four cached plans" do
    let(:max_cached_plans_count) { 4 }
    let(:user_serializer) { Class.new(super()) { preset :first_name, only: :first_name } }

    it "caches the same names in only, with, except and preset separately" do
      only_plan = plan(only: :first_name)
      with_plan = plan(with: :first_name)
      except_plan = plan(except: :first_name)
      preset_plan = plan(preset: :first_name)

      expect(only_plan).to satisfy_attribute_names(first_name: nil)
      expect(with_plan).to satisfy_attribute_names(first_name: nil, last_name: nil, address: {city: nil, zip: nil})
      expect(except_plan).to satisfy_attribute_names(last_name: nil, address: {city: nil, zip: nil})
      expect(preset_plan).to satisfy_attribute_names(first_name: nil)
      expect(preset_plan).not_to equal only_plan

      expect(plan(only: :first_name)).to equal only_plan
      expect(plan(with: :first_name)).to equal with_plan
      expect(plan(except: :first_name)).to equal except_plan
      expect(plan(preset: :first_name)).to equal preset_plan
    end
  end
end
