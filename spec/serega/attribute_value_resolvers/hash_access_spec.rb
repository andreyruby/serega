# frozen_string_literal: true

# A Hash-like record that is not `is_a?(Hash)` — hash_access dispatches purely
# through this reader interface (#[], #fetch), so any object providing it
# works, not only actual Hash instances.
class HashAccessSpecHashLikeRecord
  def initialize(data)
    @data = data
  end

  def [](key)
    @data[key]
  end

  def fetch(key, &block)
    @data.fetch(key, &block)
  end
end

RSpec.describe Serega::AttributeValueResolvers::HashAccessResolver do
  let(:serializer) { Class.new(Serega) }

  describe "without the :hash_access option" do
    it "keeps core method access — Hash records are not treated specially" do
      serializer.attribute :first_name

      expect { serializer.to_h({first_name: "Kate"}) }
        .to raise_error NoMethodError, /undefined method [`']first_name'/
    end
  end

  describe "with `hash_access: true` (shorthand for config.hash_access.default_mode, :symbol by default)" do
    it "reads symbol keys from Hash records" do
      serializer.attribute :first_name, hash_access: true
      expect(serializer.to_h({first_name: "Kate"})).to eq(first_name: "Kate")
    end

    it "does not read string keys with the default :symbol mode" do
      serializer.attribute :first_name, hash_access: true
      expect { serializer.to_h({"first_name" => "Kate"}) }.to raise_error KeyError, /key not found: :first_name/
    end

    it "reads Hash-like records that are not literally a Hash" do
      serializer.attribute :first_name, hash_access: true
      record = HashAccessSpecHashLikeRecord.new(first_name: "Kate")
      expect(serializer.to_h(record)).to eq(first_name: "Kate")
    end

    it "uses config.hash_access.default_allow_missing_key" do
      serializer.config.hash_access.default_allow_missing_key = true
      serializer.attribute :first_name, hash_access: true

      expect(serializer.to_h({})).to eq(first_name: nil)
    end
  end

  describe "with `hash_access: false`" do
    it "keeps core method access" do
      serializer.attribute :first_name, hash_access: false

      expect { serializer.to_h({first_name: "Kate"}) }
        .to raise_error NoMethodError, /undefined method [`']first_name'/
    end
  end

  describe "with :symbol mode" do
    before { serializer.attribute :first_name, hash_access: :symbol }

    it "reads symbol keys from Hash records" do
      expect(serializer.to_h({first_name: "Kate"})).to eq(first_name: "Kate")
    end

    it "reads Hash-like records that are not literally a Hash" do
      record = HashAccessSpecHashLikeRecord.new(first_name: "Kate")
      expect(serializer.to_h(record)).to eq(first_name: "Kate")
    end

    it "serializes a collection mixing real Hashes and Hash-like records" do
      record = HashAccessSpecHashLikeRecord.new(first_name: "Nash")
      result = serializer.to_h([{first_name: "Kate"}, record])
      expect(result).to eq [{first_name: "Kate"}, {first_name: "Nash"}]
    end

    it "raises a labeled KeyError on a missing key" do
      expect { serializer.to_h({name: "Kate"}) }.to raise_error KeyError, <<~MESSAGE.strip
        key not found: :first_name
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

    it "reads Hash-like records that are not literally a Hash" do
      serializer.attribute :first_name, hash_access: :string
      record = HashAccessSpecHashLikeRecord.new("first_name" => "Kate")
      expect(serializer.to_h(record)).to eq(first_name: "Kate")
    end
  end

  describe "config.hash_access.default_mode" do
    it "defaults to :symbol" do
      expect(serializer.config.hash_access.default_mode).to eq(:symbol)
    end

    it "changes what `hash_access: true` resolves to" do
      serializer.config.hash_access.default_mode = :string
      serializer.attribute :first_name, hash_access: true

      expect(serializer.to_h({"first_name" => "Kate"})).to eq(first_name: "Kate")
    end

    it "also applies to a Hash form omitting :mode" do
      serializer.config.hash_access.default_mode = :string
      serializer.attribute :first_name, hash_access: {allow_missing_key: true}

      expect(serializer.to_h({"first_name" => "Kate"})).to eq(first_name: "Kate")
    end

    it "raises on an unknown mode" do
      expect { serializer.config.hash_access.default_mode = :fetch }
        .to raise_error Serega::SeregaError, "Invalid hash_access default_mode :fetch. Allowed modes: :symbol, :string"
    end

    it "can not be set to `true` — `true` is only an attribute-level shorthand for the default mode" do
      expect { serializer.config.hash_access.default_mode = true }
        .to raise_error Serega::SeregaError, "Invalid hash_access default_mode true. Allowed modes: :symbol, :string"
    end
  end

  describe "with the :allow_missing_key sub-option" do
    it "resolves a missing key to nil" do
      serializer.attribute :middle_name, hash_access: {mode: :symbol, allow_missing_key: true}
      expect(serializer.to_h({})).to eq(middle_name: nil)
    end

    it "replaces the missing key nil with the :default option value" do
      serializer.attribute :middle_name, hash_access: {allow_missing_key: true}, default: "-"
      expect(serializer.to_h({})).to eq(middle_name: "-")
    end

    it "reads Hash-like records that are not literally a Hash via #[]" do
      serializer.attribute :nickname, hash_access: {allow_missing_key: true}
      record = HashAccessSpecHashLikeRecord.new({})
      expect(serializer.to_h(record)).to eq(nickname: nil)
    end

    it "keeps strict access with explicit `allow_missing_key: false`" do
      serializer.config.hash_access.default_allow_missing_key = true
      serializer.attribute :middle_name, hash_access: {mode: :symbol, allow_missing_key: false}

      expect { serializer.to_h({}) }.to raise_error KeyError, /key not found: :middle_name/
    end

    it "reads with the default mode when :mode is omitted from the Hash form" do
      serializer.attribute :first_name, hash_access: {allow_missing_key: true}

      expect(serializer.to_h({first_name: "Kate"})).to eq(first_name: "Kate")
    end

    it "reads the Hash's own default value for a missing key (:symbol mode)" do
      serializer.attribute :count, hash_access: {mode: :symbol, allow_missing_key: true}
      expect(serializer.to_h(Hash.new(0))).to eq(count: 0)
    end

    it "reads the Hash's own default value for a missing key (:string mode)" do
      serializer.attribute :count, hash_access: {mode: :string, allow_missing_key: true}
      expect(serializer.to_h(Hash.new(0))).to eq(count: 0)
    end
  end

  describe "with a record's own default value (a Hash carrying a default value/default_proc)" do
    it "reads the default even in strict mode (:symbol mode)" do
      serializer.attribute :count, hash_access: :symbol
      expect(serializer.to_h(Hash.new(0))).to eq(count: 0)
    end

    it "reads the default even in strict mode (:string mode)" do
      serializer.attribute :count, hash_access: :string
      expect(serializer.to_h(Hash.new(0))).to eq(count: 0)
    end

    it "still raises in strict mode when the Hash has no default" do
      serializer.attribute :count, hash_access: :symbol
      expect { serializer.to_h({}) }.to raise_error KeyError, /key not found: :count/
    end
  end

  describe "with the :delegate option" do
    it "prohibits the attribute-level :hash_access option" do
      expect { serializer.attribute :city, delegate: {to: :address}, hash_access: :symbol }
        .to raise_error Serega::SeregaError,
          "Option :hash_access can not be used together with option :delegate." \
          " Use the delegate :to_hash_access (intermediate step) and" \
          " :hash_access (final step) sub-options instead"
    end

    it "reads both steps by their own modes" do
      serializer.attribute :city, delegate: {to: :address, to_hash_access: :string, hash_access: :symbol}
      expect(serializer.to_h({"address" => {city: "Paris"}})).to eq(city: "Paris")
    end

    it "keeps the final step a plain method read when only :to_hash_access is set" do
      serializer.attribute :city, delegate: {to: :address, to_hash_access: :symbol}
      address = double(city: "Paris")
      expect(serializer.to_h({address: address})).to eq(city: "Paris")
    end

    it "reads real methods of a Hash intermediate when only :to_hash_access is set" do
      serializer.attribute :address_fields, delegate: {to: :address, method: :size, to_hash_access: :symbol}
      expect(serializer.to_h({address: {city: "Paris"}})).to eq(address_fields: 1)
    end

    it "keeps the intermediate step a plain method read when only :hash_access is set" do
      serializer.attribute :city, delegate: {to: :address, hash_access: :symbol}
      user = double(address: {city: "Paris"})
      expect(serializer.to_h(user)).to eq(city: "Paris")
    end

    it "honors the delegate :method sub-option as the final key" do
      serializer.attribute :city, delegate: {to: :address, method: :town, to_hash_access: :symbol, hash_access: :symbol}
      expect(serializer.to_h({address: {town: "Paris"}})).to eq(city: "Paris")
    end

    it "re-checks each step at runtime (hash-access steps reading Hash-like non-Hash objects)" do
      serializer.attribute :city, delegate: {to: :address, to_hash_access: :symbol, hash_access: :symbol}
      user = HashAccessSpecHashLikeRecord.new(address: HashAccessSpecHashLikeRecord.new(city: "Paris"))
      expect(serializer.to_h(user)).to eq(city: "Paris")
    end

    it "raises a labeled KeyError on a missing intermediate key" do
      serializer.attribute :city, delegate: {to: :address, to_hash_access: :symbol}
      expect { serializer.to_h({first_name: "Kate"}) }.to raise_error KeyError, <<~MESSAGE.strip
        key not found: :address
        (when serializing 'city' attribute in #{serializer})
      MESSAGE
    end

    it "raises on a missing intermediate key" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, to_hash_access: :symbol}
      expect { serializer.to_h({first_name: "Kate"}) }.to raise_error KeyError, /key not found: :address/
    end

    it "resolves a missing intermediate key to nil with the intermediate's own :allow_missing_key sub-option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, to_hash_access: {mode: :symbol, allow_missing_key: true}}
      expect(serializer.to_h({first_name: "Kate"})).to eq(city: nil)
    end

    it "resolves a nil intermediate value to nil with the delegate :allow_nil option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, to_hash_access: :symbol}
      expect(serializer.to_h({address: nil})).to eq(city: nil)
    end

    it "reads the final value through a present intermediate with the delegate :allow_nil option" do
      serializer.attribute :city, delegate: {to: :address, allow_nil: true, to_hash_access: :symbol, hash_access: :symbol}
      expect(serializer.to_h({address: {city: "Paris"}})).to eq(city: "Paris")
    end

    it "raises a labeled KeyError on a missing final key" do
      serializer.attribute :city, delegate: {to: :address, to_hash_access: :symbol, hash_access: :symbol}
      expect { serializer.to_h({address: {street: "Khreshchatyk"}}) }.to raise_error KeyError, <<~MESSAGE.strip
        key not found: :city
        (when serializing 'city' attribute in #{serializer})
      MESSAGE
    end

    it "resolves a missing final key to nil with `hash_access: {allow_missing_key: true}`" do
      serializer.attribute :city, delegate: {to: :address, to_hash_access: :symbol, hash_access: {allow_missing_key: true}}
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
