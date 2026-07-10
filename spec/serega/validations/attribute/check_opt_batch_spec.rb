# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptBatch do
  subject(:check) { described_class.call(serializer, opts) }

  let(:serializer) { Class.new(Serega) }
  let(:opts) { {} }

  before do
    serializer.batch_loaders[:test_loader] = proc {}
  end

  it "allows no :batch option" do
    opts[:foo] = nil
    expect { check }.not_to raise_error
  end

  it "allows :batch option to be true" do
    opts[:batch] = true
    expect { check }.not_to raise_error
  end

  it "allows :batch option to be a proc" do
    opts[:batch] = proc {}
    expect { check }.not_to raise_error
  end

  it "allows :batch option to be a symbol of defined loader" do
    opts[:batch] = :test_loader
    expect { check }.not_to raise_error
  end

  it "allows :batch option to be a string of defined loader" do
    opts[:batch] = "test_loader"
    expect { check }.not_to raise_error
  end

  it "raises error when batch loader is not defined" do
    opts[:batch] = :undefined_loader
    expect { check }.to raise_error Serega::SeregaError, "Batch loader with name `:undefined_loader` is not defined"
  end

  context "when :batch is a hash" do
    it "checks allowed keys" do
      opts[:batch] = {use: :test_loader, id: :id, foo: nil}
      expect { check }.to raise_error Serega::SeregaError, /foo/
    end

    it "allows :use option with defined loader" do
      opts[:batch] = {use: :test_loader}
      expect { check }.not_to raise_error
    end

    it "allows :use option with proc" do
      opts[:batch] = {use: proc {}}
      expect { check }.not_to raise_error
    end

    it "allows sole :id option" do
      opts[:batch] = {id: :other_id}
      expect { check }.not_to raise_error
    end

    it "raises error when :use loader is not defined" do
      opts[:batch] = {use: :undefined_loader}
      expect { check }.to raise_error Serega::SeregaError, "Batch loader with name `:undefined_loader` is not defined"
    end

    it "allows :id option with symbol" do
      opts[:batch] = {use: :test_loader, id: :id}
      expect { check }.not_to raise_error
    end

    it "allows :id option with string" do
      opts[:batch] = {use: :test_loader, id: "id"}
      expect { check }.not_to raise_error
    end

    it "raises error when :id is not a symbol or string" do
      opts[:batch] = {use: :test_loader, id: 123}
      expect { check }.to raise_error Serega::SeregaError, "Invalid batch option `:id` value, it can be a Symbol or a String"
    end
  end

  context "with multiple loaders" do
    before do
      serializer.batch_loaders[:loader1] = proc {}
      serializer.batch_loaders[:loader2] = proc {}
    end

    it "allows multiple loaders with :value option" do
      opts[:batch] = {use: [:loader1, :loader2]}
      opts[:value] = proc {}
      expect { check }.not_to raise_error
    end

    it "raises error when multiple loaders without :value option" do
      opts[:batch] = {use: [:loader1, :loader2]}
      expect { check }.to raise_error Serega::SeregaError, "Attribute :value option should be provided when selecting multiple batch loaders"
    end

    it "raises error when multiple loaders with :id option" do
      opts[:batch] = {use: [:loader1, :loader2], id: :id}
      expect { check }.to raise_error Serega::SeregaError, "Option `batch.id` should not be used with multiple loaders provided in `batch.use`"
    end

    it "raises error when one of multiple loaders is not defined" do
      opts[:batch] = {use: [:loader1, :undefined_loader]}
      opts[:value] = proc {}
      expect { check }.to raise_error Serega::SeregaError, "Batch loader with name `:undefined_loader` is not defined"
    end
  end

  context "with edge cases" do
    it "raises error when batch loader name is nil" do
      opts[:batch] = nil
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :batch => nil. Must have a Hash value"
    end

    it "raises error when batch loader name is empty string" do
      opts[:batch] = ""
      expect { check }.to raise_error Serega::SeregaError, "Batch loader with name `\"\"` is not defined"
    end

    it "raises error when batch loader name is empty symbol" do
      opts[:batch] = :""
      expect { check }.to raise_error Serega::SeregaError, "Batch loader with name `:\"\"` is not defined"
    end

    it "raises error when :batch is array but not in :use" do
      opts[:batch] = [:test_loader]
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :batch => [:test_loader]. Must have a Hash value"
    end

    it "raises error when :batch is number" do
      opts[:batch] = 123
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :batch => 123. Must have a Hash value"
    end
  end

  context "with other options" do
    it "prohibits to use with :method opt" do
      opts.merge!(batch: :test_loader, method: :method)
      expect { check }.to raise_error Serega::SeregaError, "Option :batch can not be used together with option :method"
    end

    it "prohibits to use with :const opt" do
      opts.merge!(batch: :test_loader, const: 1)
      expect { check }.to raise_error Serega::SeregaError, "Option :batch can not be used together with option :const"
    end

    it "prohibits to use with :delegate opt" do
      opts.merge!(batch: :test_loader, delegate: {to: :foo})
      expect { check }.to raise_error Serega::SeregaError, "Option :batch can not be used together with option :delegate"
    end

    it "prohibits to use :id with :value option" do
      opts.merge!(batch: {use: :test_loader, id: :id}, value: proc {})
      expect { check }.to raise_error Serega::SeregaError, "Option `batch.id` should not be used when :value option provided directly"
    end

    it "allows :id without :value option" do
      opts[:batch] = {use: :test_loader, id: :id}
      expect { check }.not_to raise_error
    end
  end
end
