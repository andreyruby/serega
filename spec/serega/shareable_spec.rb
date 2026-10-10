# frozen_string_literal: true

require "support/ractors"

RSpec.describe Serega::SeregaShareable, if: defined?(Ractor) do
  subject(:serialize_in_ractor) { run_in_ractor(user_serializer) { |serializer| serializer.to_h(1) } }

  let(:user_serializer) { Class.new(Serega) { attribute :name, const: "Ann" }.freeze }

  it "makes the serializer definitions shareable between Ractors" do
    expect(Ractor.shareable?(user_serializer.attributes)).to be true
    expect(Ractor.shareable?(user_serializer.config)).to be true
    expect(Ractor.shareable?(user_serializer.plan_cache)).to be true
  end

  it "serializes in another Ractor" do
    expect(serialize_in_ractor).to eq(name: "Ann")
  end

  context "with an attribute block that can not be shared" do
    let(:user_serializer) do
      suffix = +"!"
      Class.new(Serega) { attribute :name, value: proc { |user| user.name + suffix } }.freeze
    end

    it "raises an error with the attribute location in another Ractor" do
      location = user_serializer.attributes[:name].location

      expect { serialize_in_ractor }.to raise_error Serega::SeregaError,
        /\AAttribute :name of #{user_serializer} can not be shared between Ractors \(#{location}\): /
    end
  end

  context "with a batch loader that can not be shared" do
    let(:user_serializer) do
      ratings = {}
      Class.new(Serega) { batch(:ratings) { |_users| ratings } }.freeze
    end

    it "raises an error with the batch loader name in another Ractor" do
      expect { serialize_in_ractor }.to raise_error Serega::SeregaError,
        /\ABatch loader :ratings of #{user_serializer} can not be shared between Ractors: /
    end
  end

  context "with a formatter that can not be shared" do
    let(:user_serializer) do
      currency = +"USD"
      Class.new(Serega) { formatter(:money) { |cents| "#{cents} #{currency}" } }.freeze
    end

    it "raises an error with the formatter name in another Ractor" do
      expect { serialize_in_ractor }.to raise_error Serega::SeregaError,
        /\AFormatter :money of #{user_serializer} can not be shared between Ractors: /
    end
  end

  context "with another definition that can not be shared" do
    let(:user_serializer) do
      preloaded = []
      Class.new(Serega) { preload_with { |objects, _preloads| preloaded.concat(objects) } }.freeze
    end

    it "raises an error with the serializer name in another Ractor" do
      expect { serialize_in_ractor }.to raise_error Serega::SeregaError, /\A#{user_serializer} can not be shared between Ractors: /
    end
  end

  context "with a constant value that can not be shared" do
    let(:user_serializer) { Class.new(Serega) { attribute :lock, const: Thread::Mutex.new }.freeze }

    it "serializes in the main Ractor" do
      expect(user_serializer.to_h(1)[:lock]).to be_a Thread::Mutex
    end

    it "raises an error in another Ractor" do
      expect { serialize_in_ractor }.to raise_error Serega::SeregaError, /can not be shared between Ractors/
    end
  end
end
