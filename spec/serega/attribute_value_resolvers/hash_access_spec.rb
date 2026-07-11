# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers::HashAccessResolver do
  let(:serializer) { Class.new(Serega) }

  describe "without the :hash_access option" do
    it "keeps core method access — Hash records are not treated specially" do
      serializer.attribute :first_name

      expect { serializer.to_h({first_name: "Kate"}) }
        .to raise_error NoMethodError, /undefined method 'first_name'/
    end
  end

  describe "with `hash_access: true` (config defaults)" do
    it "reads symbol keys from Hash records with default config" do
      serializer.attribute :first_name, hash_access: true
      expect(serializer.to_h({first_name: "Kate"})).to eq(first_name: "Kate")
    end

    it "uses config.hash_access :default_mode" do
      serializer.config.hash_access = {default_mode: :string}
      serializer.attribute :first_name, hash_access: true

      expect(serializer.to_h({"first_name" => "Kate"})).to eq(first_name: "Kate")
    end

    it "uses config.hash_access :default_allow_nil" do
      serializer.config.hash_access = {default_allow_nil: true}
      serializer.attribute :first_name, hash_access: true

      expect(serializer.to_h({})).to eq(first_name: nil)
    end
  end

  describe "with `hash_access: false`" do
    it "keeps core method access" do
      serializer.attribute :first_name, hash_access: false

      expect { serializer.to_h({first_name: "Kate"}) }
        .to raise_error NoMethodError, /undefined method 'first_name'/
    end
  end

  describe "with :symbol mode" do
    before { serializer.attribute :first_name, hash_access: :symbol }

    it "reads symbol keys from Hash records" do
      expect(serializer.to_h({first_name: "Kate"})).to eq(first_name: "Kate")
    end

    it "calls methods on non-Hash records" do
      user = double(first_name: "Kate")
      expect(serializer.to_h(user)).to eq(first_name: "Kate")
    end

    it "serializes mixed collections" do
      user = double(first_name: "Nash")
      result = serializer.to_h([{first_name: "Kate"}, user])
      expect(result).to eq [{first_name: "Kate"}, {first_name: "Nash"}]
    end

    it "raises a labeled SeregaError on a missing key" do
      expect { serializer.to_h({name: "Kate"}) }.to raise_error Serega::SeregaError, <<~MESSAGE.strip
        Hash has no :first_name key
        (when serializing 'first_name' attribute in #{serializer})
      MESSAGE
    end
  end

  describe "with :string mode" do
    it "reads string keys from Hash records" do
      serializer.attribute :first_name, hash_access: :string
      expect(serializer.to_h({"first_name" => "Kate"})).to eq(first_name: "Kate")
    end

    it "reads string keys that are not valid method names via the :method option" do
      serializer.attribute :first_name, method: :"first-name", hash_access: :string
      expect(serializer.to_h({"first-name" => "Kate"})).to eq(first_name: "Kate")
    end

    it "calls methods on non-Hash records" do
      serializer.attribute :first_name, hash_access: :string
      user = double(first_name: "Kate")
      expect(serializer.to_h(user)).to eq(first_name: "Kate")
    end
  end

  describe "with :auto mode" do
    it "prefers the symbol key" do
      serializer.attribute :first_name, hash_access: :auto
      expect(serializer.to_h({:first_name => "symbol", "first_name" => "string"})).to eq(first_name: "symbol")
    end

    it "falls back to the string key" do
      serializer.attribute :first_name, hash_access: :auto
      expect(serializer.to_h({"first_name" => "string"})).to eq(first_name: "string")
    end

    it "falls back to the method" do
      serializer.attribute :size, hash_access: :auto
      expect(serializer.to_h({first_name: "Kate"})).to eq(size: 1)
    end

    it "raises a labeled SeregaError when nothing matches" do
      serializer.attribute :last_name, hash_access: :auto
      expect { serializer.to_h({first_name: "Kate"}) }.to raise_error Serega::SeregaError, <<~MESSAGE.strip
        Hash has no :last_name or "last_name" key and no #last_name method
        (when serializing 'last_name' attribute in #{serializer})
      MESSAGE
    end

    it "resolves to nil when nothing matches with allow_nil" do
      serializer.attribute :last_name, hash_access: {mode: :auto, allow_nil: true}
      expect(serializer.to_h({first_name: "Kate"})).to eq(last_name: nil)
    end

    it "resolves a missing method on non-Hash objects to nil with allow_nil" do
      serializer.attribute :nickname, hash_access: {mode: :auto, allow_nil: true}
      user = Struct.new(:name).new("Kate")

      expect(serializer.to_h(user)).to eq(nickname: nil)
    end

    it "serializes mixed hash/object collections with optional fields with allow_nil" do
      serializer.attribute :name, hash_access: {mode: :auto, allow_nil: true}
      serializer.attribute :nickname, hash_access: {mode: :auto, allow_nil: true}
      user = Struct.new(:name).new("from object")

      result = serializer.to_h([{name: "from hash"}, user, {}])
      expect(result).to eq [
        {name: "from hash", nickname: nil},
        {name: "from object", nickname: nil},
        {name: nil, nickname: nil}
      ]
    end

    it "keeps raising NoMethodError on non-Hash objects without allow_nil" do
      serializer.attribute :nickname, hash_access: :auto
      user = Struct.new(:name).new("Kate")

      expect { serializer.to_h(user) }.to raise_error NoMethodError, /undefined method 'nickname'/
    end
  end

  describe "with the :allow_nil sub-option" do
    it "resolves a missing key to nil" do
      serializer.attribute :middle_name, hash_access: {mode: :symbol, allow_nil: true}
      expect(serializer.to_h({})).to eq(middle_name: nil)
    end

    it "replaces the missing key nil with the :default option value" do
      serializer.attribute :middle_name, hash_access: {allow_nil: true}, default: "-"
      expect(serializer.to_h({})).to eq(middle_name: "-")
    end

    it "keeps strict access with explicit `allow_nil: false`" do
      serializer.config.hash_access = {default_allow_nil: true}
      serializer.attribute :middle_name, hash_access: {allow_nil: false}

      expect { serializer.to_h({}) }.to raise_error Serega::SeregaError, /Hash has no :middle_name key/
    end

    it "fills the omitted :mode from config defaults" do
      serializer.config.hash_access = {default_mode: :string}
      serializer.attribute :first_name, hash_access: {allow_nil: true}

      expect(serializer.to_h({"first_name" => "Kate"})).to eq(first_name: "Kate")
    end
  end

  describe "with the :delegate option" do
    it "prohibits the attribute-level :hash_access option" do
      expect { serializer.attribute :city, delegate: {to: :address}, hash_access: :symbol }
        .to raise_error Serega::SeregaError,
          "Option :hash_access can not be used together with option :delegate." \
          " Use the delegate :hash_access (intermediate step) and" \
          " :method_hash_access (final step) sub-options instead"
    end

    it "reads both steps by their own modes" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :string, method_hash_access: :symbol}
      expect(serializer.to_h({"address" => {city: "Kyiv"}})).to eq(city: "Kyiv")
    end

    it "uses config defaults for `hash_access: true` and `method_hash_access: true`" do
      serializer.config.hash_access = {default_mode: :string}
      serializer.attribute :city, delegate: {to: :address, hash_access: true, method_hash_access: true}

      expect(serializer.to_h({"address" => {"city" => "Kyiv"}})).to eq(city: "Kyiv")
    end

    it "keeps the final step a plain method read when only :hash_access is set" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :symbol}
      address = double(city: "Kyiv")
      expect(serializer.to_h({address: address})).to eq(city: "Kyiv")
    end

    it "reads real methods of a Hash intermediate when only :hash_access is set" do
      serializer.attribute :address_fields, delegate: {to: :address, method: :size, hash_access: :symbol}
      expect(serializer.to_h({address: {city: "Kyiv"}})).to eq(address_fields: 1)
    end

    it "keeps the intermediate step a plain method read when only :method_hash_access is set" do
      serializer.attribute :city, delegate: {to: :address, method_hash_access: :symbol}
      user = double(address: {city: "Kyiv"})
      expect(serializer.to_h(user)).to eq(city: "Kyiv")
    end

    it "honors the delegate :method sub-option as the final key" do
      serializer.attribute :city, delegate: {to: :address, method: :town, hash_access: :symbol, method_hash_access: :symbol}
      expect(serializer.to_h({address: {town: "Kyiv"}})).to eq(city: "Kyiv")
    end

    it "re-checks each step at runtime (hash-access steps reading non-Hash objects)" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :symbol, method_hash_access: :symbol}
      user = double(address: double(city: "Kyiv"))
      expect(serializer.to_h(user)).to eq(city: "Kyiv")
    end

    it "raises a labeled SeregaError on a missing intermediate key" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :symbol}
      expect { serializer.to_h({first_name: "Kate"}) }.to raise_error Serega::SeregaError, <<~MESSAGE.strip
        Hash has no :address key
        (when serializing 'city' attribute in #{serializer})
      MESSAGE
    end

    it "resolves a missing intermediate key to nil with the delegate :allow_nil option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, hash_access: :symbol}
      expect(serializer.to_h({first_name: "Kate"})).to eq(city: nil)
    end

    it "resolves a nil intermediate value to nil with the delegate :allow_nil option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, hash_access: :symbol}
      expect(serializer.to_h({address: nil})).to eq(city: nil)
    end

    it "resolves a missing intermediate method on non-Hash objects to nil with :auto and the delegate :allow_nil option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, hash_access: :auto}
      user = Struct.new(:name).new("Kate")

      expect(serializer.to_h(user)).to eq(city: nil)
    end

    it "reads the final value through a present intermediate with the delegate :allow_nil option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, hash_access: :symbol, method_hash_access: :symbol}
      expect(serializer.to_h({address: {city: "Kyiv"}})).to eq(city: "Kyiv")
    end

    it "raises a labeled SeregaError on a missing final key" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :symbol, method_hash_access: :symbol}
      expect { serializer.to_h({address: {street: "Khreshchatyk"}}) }.to raise_error Serega::SeregaError, <<~MESSAGE.strip
        Hash has no :city key
        (when serializing 'city' attribute in #{serializer})
      MESSAGE
    end

    it "resolves a missing final key to nil with `method_hash_access: {allow_nil: true}`" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :symbol, method_hash_access: {allow_nil: true}}
      expect(serializer.to_h({address: {street: "Khreshchatyk"}})).to eq(city: nil)
    end
  end

  describe "with nested serializers" do
    it "finds the nested value by mode and serializes it with the nested serializer" do
      profile_serializer = Class.new(Serega) { attribute :bio, hash_access: true }
      serializer.attribute :profile, serializer: profile_serializer, hash_access: true

      user = {profile: {bio: "hi"}}
      expect(serializer.to_h(user)).to eq(profile: {bio: "hi"})
    end

    it "serializes arrays of hashes as collections" do
      comment_serializer = Class.new(Serega) { attribute :text, hash_access: true }
      serializer.attribute :comments, serializer: comment_serializer, hash_access: true

      user = {comments: [{text: "first"}, {text: "second"}]}
      expect(serializer.to_h(user)).to eq(comments: [{text: "first"}, {text: "second"}])
    end
  end
end
