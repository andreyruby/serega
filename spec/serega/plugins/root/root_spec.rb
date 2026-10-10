# frozen_string_literal: true

load_plugin_code :root

RSpec.describe Serega::SeregaPlugins::Root do
  describe "loading" do
    let(:serializer) { Class.new(Serega) }

    it "set default root" do
      serializer.plugin :root

      expect(serializer.config.root.one).to be described_class::ROOT_DEFAULT
      expect(serializer.config.root.many).to be described_class::ROOT_DEFAULT
    end

    it "set custom root" do
      serializer.plugin :root, root: :records

      expect(serializer.config.root.one).to be :records
      expect(serializer.config.root.many).to be :records
    end

    it "set custom root per serialization type" do
      serializer.plugin :root, root_one: :user, root_many: :people

      expect(serializer.config.root.one).to be :user
      expect(serializer.config.root.many).to be :people
    end

    it "allows to skip root by default" do
      serializer.plugin :root, root: nil

      expect(serializer.config.root.one).to be_nil
      expect(serializer.config.root.many).to be_nil
    end

    it "allows to skip root for one record serialization" do
      serializer.plugin :root, root_one: nil

      expect(serializer.config.root.one).to be_nil
      expect(serializer.config.root.many).to be described_class::ROOT_DEFAULT
    end

    it "allows to skip root for many records serialization" do
      serializer.plugin :root, root_many: nil

      expect(serializer.config.root.one).to be described_class::ROOT_DEFAULT
      expect(serializer.config.root.many).to be_nil
    end

    it "raises error if plugin defined with unknown option" do
      serializer = Class.new(Serega)
      expect { serializer.plugin(:root, foo: :bar) }
        .to raise_error Serega::SeregaError, <<~MESSAGE.strip
          Plugin :root does not accept the :foo option. Allowed options:
            - :root [String, Symbol, nil] Specifies common root keyword used when serializing one or multiple objects
            - :root_one [String, Symbol, nil] Specifies root keyword used when serializing one object
            - :root_many [String, Symbol, nil] Specifies root keyword used when serializing multiple objects
        MESSAGE
    end
  end

  describe "configuration" do
    let(:serializer) { Class.new(Serega) { plugin :root } }

    it "preserves root config" do
      root1 = serializer.config.root
      root2 = serializer.config.root
      expect(root1).to be root2
    end

    it "allows to change root via #one= and #many= methods" do
      root = serializer.config.root
      root.one = :new_one
      root.many = :new_many

      expect(root.one).to eq :new_one
      expect(root.many).to eq :new_many
    end
  end

  describe "serialization" do
    let(:response) { user_serializer.new.to_h(user) }

    context "with default root" do
      let(:base_serializer) { Class.new(Serega) { plugin :root } }
      let(:user) { double(first_name: "FIRST_NAME") }

      let(:user_serializer) do
        Class.new(base_serializer) do
          attribute :first_name
          freeze
        end
      end

      it "adds default root key to single object response" do
        response = user_serializer.new.to_h(user)
        expect(response).to eq(data: {first_name: "FIRST_NAME"})
      end

      it "adds default root key to multiple objects response" do
        response = user_serializer.new.to_h([user])
        expect(response).to eq(data: [{first_name: "FIRST_NAME"}])
      end
    end

    context "with different root key for one or many serialized resources" do
      let(:user) { double(first_name: "FIRST_NAME") }

      let(:user_serializer) do
        Class.new(Serega) do
          plugin :root, root_one: "user", root_many: "users"
          attribute :first_name
          freeze
        end
      end

      it "adds root key to single object response" do
        response = user_serializer.new.to_h(user)
        expect(response).to eq("user" => {first_name: "FIRST_NAME"})
      end

      it "adds root key to multiple objects response" do
        response = user_serializer.new.to_h([user])
        expect(response).to eq("users" => [{first_name: "FIRST_NAME"}])
      end
    end

    context "with root provided as DSL method" do
      let(:user) { double(first_name: "FIRST_NAME") }

      let(:user_serializer) do
        Class.new(Serega) do
          plugin :root
          root one: :customer, many: :customers
          attribute :first_name
          freeze
        end
      end

      it "adds root key to single object response" do
        response = user_serializer.new.to_h(user)
        expect(response).to eq(customer: {first_name: "FIRST_NAME"})
      end

      it "adds root key to multiple objects response" do
        response = user_serializer.new.to_h([user])
        expect(response).to eq(customers: [{first_name: "FIRST_NAME"}])
      end
    end

    context "with root provided as serialization option" do
      let(:user) { double(first_name: "FIRST_NAME") }

      let(:user_serializer) do
        Class.new(Serega) do
          plugin :root
          attribute :first_name
          freeze
        end
      end

      it "adds root key to single object response" do
        response = user_serializer.new.to_h(user, root: :customer)
        expect(response).to eq(customer: {first_name: "FIRST_NAME"})
      end

      it "adds root key to multiple objects response" do
        response = user_serializer.new.to_h([user], root: :customers)
        expect(response).to eq(customers: [{first_name: "FIRST_NAME"}])
      end

      it "removes root key when nil provided" do
        response = user_serializer.new.to_h([user], root: nil)
        expect(response).to eq([{first_name: "FIRST_NAME"}])
      end
    end
  end

  describe "serialization to data" do
    subject(:result) { user_serializer.to_data(users, serialize_opts) }

    let(:user_serializer) do
      Class.new(Serega) do
        plugin :root, root_one: :user, root_many: :users
        attribute :first_name
        freeze
      end
    end

    let(:user) { double(first_name: "FIRST_NAME") }
    let(:users) { user }
    let(:serialize_opts) { {} }

    it "returns a Hash with a Data object under the one-root key" do
      expect(result.keys).to eq [:user]
      expect(result[:user]).to be_a(Data)
      expect(result[:user].to_h).to eq(first_name: "FIRST_NAME")
    end

    context "with a collection" do
      let(:users) { [user] }

      it "returns a Hash with Data objects under the many-root key" do
        expect(result.keys).to eq [:users]
        expect(result[:users].map(&:to_h)).to eq [{first_name: "FIRST_NAME"}]
      end
    end

    context "with the root serialization option" do
      let(:serialize_opts) { {root: :customer} }

      it "returns a Hash with the provided root key" do
        expect(result.keys).to eq [:customer]
      end
    end

    context "with the nil root serialization option" do
      let(:serialize_opts) { {root: nil} }

      it "returns the Data object" do
        expect(result).to be_a(Data)
        expect(result.to_h).to eq(first_name: "FIRST_NAME")
      end
    end
  end

  describe "serialization to structs" do
    subject(:result) { user_serializer.to_struct(users, serialize_opts) }

    let(:user_serializer) do
      Class.new(Serega) do
        plugin :root, root_one: :user, root_many: :users
        attribute :first_name
        freeze
      end
    end

    let(:user) { double(first_name: "FIRST_NAME") }
    let(:users) { user }
    let(:serialize_opts) { {} }

    it "returns a Hash with a Struct object under the one-root key" do
      expect(result.keys).to eq [:user]
      expect(result[:user]).to be_a(Struct)
      expect(result[:user].to_h).to eq(first_name: "FIRST_NAME")
    end

    context "with a collection" do
      let(:users) { [user] }

      it "returns a Hash with Struct objects under the many-root key" do
        expect(result.keys).to eq [:users]
        expect(result[:users].map(&:to_h)).to eq [{first_name: "FIRST_NAME"}]
      end
    end

    context "with the nil root serialization option" do
      let(:serialize_opts) { {root: nil} }

      it "returns the Struct object" do
        expect(result).to be_a(Struct)
        expect(result.to_h).to eq(first_name: "FIRST_NAME")
      end
    end
  end

  describe "prepare_initial_objects" do
    let(:records) { {"1" => double(first_name: "Ann"), "2" => double(first_name: "Bob")} }

    it "serializes prepared objects to hash" do
      data = records
      user_serializer = Class.new(Serega) do
        plugin :root
        prepare_initial_objects { |ids| ids.map { |id| data[id] } }
        attribute :first_name
        freeze
      end

      expect(user_serializer.to_h(["1"])).to eq(data: [{first_name: "Ann"}])
    end

    it "serializes prepared objects to data" do
      data = records
      user_serializer = Class.new(Serega) do
        plugin :root
        prepare_initial_objects { |ids| ids.map { |id| data[id] } }
        attribute :first_name
        freeze
      end

      result = user_serializer.to_data(["1"])
      expect(result[:data].first.first_name).to eq "Ann"
    end

    it "uses many root key when a single object is prepared into a collection" do
      data = records
      user_serializer = Class.new(Serega) do
        plugin :root, root_one: "user", root_many: "users"
        prepare_initial_objects { |id| [data[id]] }
        attribute :first_name
        freeze
      end

      expect(user_serializer.to_h("1")).to eq("users" => [{first_name: "Ann"}])
    end
  end

  context "when the config is deeply frozen", if: defined?(Ractor) do
    let(:frozen_config) do
      serializer_class = Class.new(Serega) do
        plugin :root
      end
      Ractor.make_shareable(serializer_class.config)
    end

    it "returns the root config" do
      expect(frozen_config.root).to be_a Serega::SeregaPlugins::Root::RootConfig
    end
  end
end
