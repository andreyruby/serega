# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::PreloadsConstructor do
  let(:base) { Class.new(Serega) }
  let(:user_serializer) { Class.new(base) }
  let(:profile_serializer) { Class.new(base) }
  let(:user_ser) { user_serializer.new }

  def plan(serializer)
    serializer.send(:plan)
  end

  it "returns empty hash when plan is nil" do
    result = described_class.call(nil)
    expect(result).to eq({})
  end

  it "returns empty hash when no attributes requested" do
    result = described_class.call(plan(user_ser))
    expect(result).to eq({})
  end

  it "returns empty hash when no attributes with preloads requested" do
    user_serializer.attribute :name

    result = described_class.call(plan(user_ser))
    expect(result).to eq({})
  end

  it "returns preloads for requested attributes" do
    user_serializer.attribute :name, preload: :profile

    result = described_class.call(plan(user_ser))
    expect(result).to eq(profile: {})
  end

  it "returns merged preloads for requested attributes" do
    user_serializer.attribute :first_name, preload: :profile
    user_serializer.attribute :phone, preload: {profile: :phones}
    user_serializer.attribute :email, preload: {profile: :emails}

    result = described_class.call(plan(user_ser))
    expect(result).to eq(profile: {phones: {}, emails: {}})
  end

  it "returns preloads generated automatically for relations" do
    user_serializer.config.auto_preload_attributes_with_serializer = true
    user_serializer.attribute :email, serializer: base

    result = described_class.call(plan(user_ser))
    expect(result).to eq(email: {})
  end

  it "returns no preloads and no nested preloads for relations when specified preloads is nil" do
    user_serializer.attribute :profile, serializer: profile_serializer, preload: nil
    profile_serializer.attribute :email, preload: :email # should not be preloaded

    result = described_class.call(plan(user_ser))
    expect(result).to eq({})
  end

  it "returns preloads for nested relations joined to root when specified preloads is empty hash" do
    user_serializer.attribute :profile, serializer: profile_serializer, preload: {}
    profile_serializer.attribute :email, preload: :email # should be preloaded to root

    result = described_class.call(plan(user_ser))
    expect(result).to eq(email: {})
  end

  it "returns preloads for nested relations joined to root when specified preloads is empty array" do
    user_serializer.attribute :profile, serializer: profile_serializer, preload: []
    profile_serializer.attribute :email, preload: :email # should be preloaded to root

    result = described_class.call(plan(user_ser))
    expect(result).to eq(email: {})
  end

  it "returns nested preloads for relations" do
    user_serializer.attribute :profile, preload: :profile, serializer: profile_serializer
    profile_serializer.attribute :email, preload: %i[confirmed_email unconfirmed_email]

    result = described_class.call(plan(user_ser))
    expect(result).to eq(profile: {confirmed_email: {}, unconfirmed_email: {}})
  end

  it "preloads nested relations for nested relation" do
    user_serializer.attribute :profile,
      serializer: profile_serializer,
      preload: {company: :profile},
      preload_path: %i[company profile]

    profile_serializer.attribute :email,
      preload: %i[confirmed_email unconfirmed_email]

    result = described_class.call(plan(user_ser))
    expect(result).to eq(company: {profile: {confirmed_email: {}, unconfirmed_email: {}}})
  end

  it "preloads nested relations to main resource if specified `preload_path` is nil" do
    user_serializer.attribute :profile, serializer: profile_serializer,
      preload: {company: :profile},
      preload_path: nil

    profile_serializer.attribute :email, preload: %i[confirmed_email unconfirmed_email]

    result = described_class.call(plan(user_ser))
    expect(result).to eq(company: {profile: {}}, confirmed_email: {}, unconfirmed_email: {})
  end

  it "preloads nested relations to main resource, specified by `preload_path`" do
    user_serializer.attribute :profile, serializer: profile_serializer,
      preload: {company: :profile},
      preload_path: :company

    profile_serializer.attribute :email, preload: %i[confirmed_email unconfirmed_email]

    result = described_class.call(plan(user_ser))
    expect(result).to eq(company: {profile: {}, confirmed_email: {}, unconfirmed_email: {}})
  end

  it "preloads nested relations to multiple resources, specified by `preload_path`" do
    user_serializer.attribute :videos, serializer: profile_serializer,
      preload: [:profile1, :profile2],
      preload_path: [[:profile1], [:profile2]]

    profile_serializer.attribute :email, preload: :email

    result = described_class.call(plan(user_ser))
    expect(result).to eq(profile1: {email: {}}, profile2: {email: {}})
  end

  it "merges preloads the same way regardless of order of preloads" do
    a = Class.new(base)
    a.attribute :a1, preload: {foo: {bar: {bazz1: {}, bazz: {}}}}
    a.attribute :a2, preload: {foo: {bar: {bazz2: {}, bazz: {last: {}}}}}

    b = Class.new(base)
    b.attribute :a1, preload: {foo: {bar: {bazz2: {}, bazz: {last: {}}}}}
    b.attribute :a2, preload: {foo: {bar: {bazz1: {}, bazz: {}}}}

    plan_a = a.new.plan
    plan_b = b.new.plan

    result1 = described_class.call(plan_a)
    result2 = described_class.call(plan_b)

    expect(result1).to eq(result2)
    expect(result1).to eq(foo: {bar: {bazz: {last: {}}, bazz1: {}, bazz2: {}}})
  end
end
