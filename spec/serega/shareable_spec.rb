# frozen_string_literal: true

RSpec.describe Serega::SeregaShareable, if: defined?(Ractor) do
  subject(:share) { described_class.call(user_serializer) }

  let(:post_serializer) { Class.new(Serega) { attribute :title } }

  let(:user_serializer) do
    posts = post_serializer

    Class.new(Serega) do
      attribute :name
      attribute :posts, serializer: posts, many: true
    end
  end

  it "makes the serializer definitions shareable between Ractors" do
    share

    expect(Ractor.shareable?(user_serializer.attributes)).to be true
    expect(Ractor.shareable?(user_serializer.config)).to be true
    expect(Ractor.shareable?(user_serializer.plan_cache)).to be true
  end

  it "freezes the serializers of the relations and leaves the serializer to Serega.freeze" do
    share

    expect(post_serializer).to be_frozen
    expect(user_serializer).not_to be_frozen
  end

  context "with a frozen relation serializer" do
    let!(:post_plan_cache) { post_serializer.freeze.plan_cache }

    it "keeps the frozen serializer as it is" do
      share

      expect(post_serializer.plan_cache).to be post_plan_cache
    end
  end

  context "with relations that refer to each other" do
    let(:user_serializer) do
      stub_const("RactorUserSerializer", Class.new(Serega) { attribute :name })
      stub_const("RactorPostSerializer", Class.new(Serega) { attribute :author, serializer: "RactorUserSerializer" })
      RactorUserSerializer.attribute :posts, serializer: "RactorPostSerializer", many: true, hide: true
      RactorUserSerializer
    end

    it "freezes each serializer once" do
      share

      expect(RactorPostSerializer).to be_frozen
    end
  end

  context "with an attribute name that can not be a Data member" do
    let(:user_serializer) do
      Class.new(Serega) do
        config.check_attribute_name = false
        attribute :name=, value: proc { "Ann" }
      end
    end

    it "builds the other modes" do
      share

      expect(user_serializer.to_h(1)).to eq(:name= => "Ann")
      expect { user_serializer.to_data(1) }.to raise_error Serega::SeregaError, /invalid data member: name=/
    end
  end

  context "with an attribute block that can not be shared" do
    let(:user_serializer) do
      suffix = +"!"
      Class.new(Serega) { attribute :name, value: proc { |user| user.name + suffix } }
    end

    it "raises an error with the attribute location" do
      location = user_serializer.attributes[:name].location

      expect { share }.to raise_error Serega::SeregaError,
        /\AAttribute :name of #{user_serializer} can not be shared between Ractors \(#{location}\): /
    end
  end

  context "with a batch loader that can not be shared" do
    let(:user_serializer) do
      ratings = {}
      Class.new(Serega) { batch(:ratings) { |_users| ratings } }
    end

    it "raises an error with the batch loader name" do
      expect { share }.to raise_error Serega::SeregaError,
        /\ABatch loader :ratings of #{user_serializer} can not be shared between Ractors: /
    end
  end

  context "with a formatter that can not be shared" do
    let(:user_serializer) do
      currency = +"USD"
      Class.new(Serega) { formatter(:money) { |cents| "#{cents} #{currency}" } }
    end

    it "raises an error with the formatter name" do
      expect { share }.to raise_error Serega::SeregaError,
        /\AFormatter :money of #{user_serializer} can not be shared between Ractors: /
    end
  end

  context "with another definition that can not be shared" do
    let(:user_serializer) do
      preloaded = []
      Class.new(Serega) { preload_with { |objects, _preloads| preloaded.concat(objects) } }
    end

    it "raises an error with the serializer name" do
      expect { share }.to raise_error Serega::SeregaError, /\A#{user_serializer} can not be shared between Ractors: /
    end
  end
end
