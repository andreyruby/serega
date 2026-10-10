# frozen_string_literal: true

load_plugin_code :string_modifiers

RSpec.describe Serega::SeregaPlugins::StringModifiers do
  describe "serialization" do
    let(:response) { user_serializer.new.to_h(user) }

    let(:base_serializer) { Class.new(Serega) { plugin :string_modifiers } }

    let(:user) { double(first_name: "FIRST NAME", post: post) }
    let(:post) { double(title: "TITLE", text: "TEXT") }

    let(:user_serializer) do
      post_ser = post_serializer
      Class.new(base_serializer) do
        attribute :first_name
        attribute :post, serializer: post_ser, hide: true
        freeze
      end
    end

    let(:post_serializer) do
      Class.new(base_serializer) do
        attribute :title
        attribute :text
        freeze
      end
    end

    it "allows to provide :only modifier as string" do
      only = "post(title)"
      response = user_serializer.new(only: only).to_h(user)
      expect(response).to eq(post: {title: "TITLE"})
    end

    context "with a visible relation" do
      let(:user_serializer) do
        post_ser = post_serializer
        Class.new(base_serializer) do
          attribute :first_name
          attribute :post, serializer: post_ser
          freeze
        end
      end

      it "allows to provide :except modifier as string" do
        except = "post(title)"
        response = user_serializer.new(except: except).to_h(user)
        expect(response).to eq(first_name: "FIRST NAME", post: {text: "TEXT"})
      end
    end

    context "with a hidden attribute in the relation serializer" do
      let(:post_serializer) do
        Class.new(base_serializer) do
          attribute :title
          attribute :text, hide: true
          freeze
        end
      end

      it "allows to provide :with modifier as string" do
        with = "post(text)"
        response = user_serializer.new(with: with).to_h(user)
        expect(response).to eq(first_name: "FIRST NAME", post: {title: "TITLE", text: "TEXT"})
      end
    end

    it "allows to provide modifiers as objects" do
      only = [:first_name]
      response = user_serializer.new(only: only).to_h(user)
      expect(response).to eq(first_name: "FIRST NAME")
    end

    it "allows to provide modifiers with :check_initiate_params option" do
      only = [:first_name]
      response = user_serializer.new(only: only, check_initiate_params: false).to_h(user)
      expect(response).to eq(first_name: "FIRST NAME")
    end

    context "with plan caching" do
      let(:base_serializer) do
        Class.new(Serega) do
          plugin :string_modifiers
          config.max_cached_plans_per_serializer_count = 1
        end
      end

      before { allow(described_class::ParseStringModifiers).to receive(:parse).and_call_original }

      it "parses the string modifiers once" do
        responses = Array.new(2) { user_serializer.new(only: "post(title)").to_h(user) }

        expect(responses).to all eq(post: {title: "TITLE"})
        expect(described_class::ParseStringModifiers).to have_received(:parse).once
      end
    end
  end
end
