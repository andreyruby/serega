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
          attribute :first_name
        end
      end

      it "adds root key to single object response" do
        user_serializer.root one: :customer
        response = user_serializer.new.to_h(user)
        expect(response).to eq(customer: {first_name: "FIRST_NAME"})
      end

      it "adds root key to multiple objects response" do
        user_serializer.root many: :customers
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
    let(:user) { double(first_name: "FIRST_NAME") }

    context "with default root (config-computed)" do
      let(:user_serializer) do
        Class.new(Serega) do
          plugin :root
          attribute :first_name
        end
      end

      it "wraps single object in a Data with default root key" do
        result = user_serializer.to_data(user)
        expect(result).to be_a(Data)
        expect(result.members).to eq [:data]
        expect(result.data).to be_a(Data)
        expect(result.data.first_name).to eq "FIRST_NAME"
      end

      it "wraps collection in a Data with default root key" do
        result = user_serializer.to_data([user])
        expect(result).to be_a(Data)
        expect(result.members).to eq [:data]
        expect(result.data).to be_an(Array)
        expect(result.data.first.first_name).to eq "FIRST_NAME"
      end
    end

    context "with different root keys for one and many" do
      let(:user_serializer) do
        Class.new(Serega) do
          plugin :root, root_one: :user, root_many: :users
          attribute :first_name
        end
      end

      it "uses one-root key for single object" do
        result = user_serializer.to_data(user)
        expect(result.members).to eq [:user]
        expect(result.user.first_name).to eq "FIRST_NAME"
      end

      it "uses many-root key for collection" do
        result = user_serializer.to_data([user])
        expect(result.members).to eq [:users]
        expect(result.users.first.first_name).to eq "FIRST_NAME"
      end
    end

    context "with root provided as serialization option" do
      let(:user_serializer) do
        Class.new(Serega) do
          plugin :root
          attribute :first_name
        end
      end

      it "uses explicit root key" do
        result = user_serializer.to_data(user, root: :customer)
        expect(result.members).to eq [:customer]
        expect(result.customer.first_name).to eq "FIRST_NAME"
      end

      it "returns plain Data (no root wrapper) when root: nil" do
        result = user_serializer.to_data(user, root: nil)
        expect(result).to be_a(Data)
        expect(result.members).to eq [:first_name]
        expect(result.first_name).to eq "FIRST_NAME"
      end
    end
  end
end
