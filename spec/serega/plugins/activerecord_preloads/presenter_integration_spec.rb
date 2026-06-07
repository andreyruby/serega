# frozen_string_literal: true

require "support/activerecord"
require "support/matchers/run_queries"

load_plugin_code :activerecord_preloads
load_plugin_code :presenter

RSpec.describe Serega::SeregaPlugins::ActiverecordPreloads do
  describe "load order with :presenter" do
    it "raises when :activerecord_preloads is loaded after :presenter" do
      serializer = Class.new(Serega) { plugin :presenter }
      error = "Plugin :activerecord_preloads must be loaded before the :presenter plugin. Please load the :activerecord_preloads plugin first"
      expect { serializer.plugin(:activerecord_preloads) }.to raise_error Serega::SeregaError, error
    end

    it "allows :presenter to be loaded after :activerecord_preloads" do
      serializer = Class.new(Serega) { plugin :activerecord_preloads }
      expect { serializer.plugin(:presenter) }.not_to raise_error
    end
  end

  describe "preloading through presenter", :with_rollback do
    let(:user1) { AR::User.create!(first_name: "Bruce", last_name: "Wayne") }
    let(:user2) { AR::User.create!(first_name: "Clark", last_name: "Kent") }

    let(:app_serializer) do
      Class.new(Serega) do
        plugin :activerecord_preloads
        plugin :presenter
      end
    end

    let(:post_serializer) do
      Class.new(app_serializer) { attribute :text }
    end

    let(:users_serializer) do
      ps = post_serializer
      Class.new(app_serializer) do
        attribute :first_name
        attribute :posts, serializer: -> { ps }, preload: :posts
      end
    end

    before do
      AR::Post.create!(user: user1, text: "post1")
      AR::Post.create!(user: user2, text: "post2")
    end

    it "preloads associations onto the underlying records, avoiding N+1" do
      data = nil
      expect { data = users_serializer.call(AR::User.all) }.to run_queries(2)
      expect(data).to eq [
        {first_name: "Bruce", posts: [{text: "post1"}]},
        {first_name: "Clark", posts: [{text: "post2"}]}
      ]
    end
  end
end
