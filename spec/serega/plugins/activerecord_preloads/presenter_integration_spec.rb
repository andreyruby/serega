# frozen_string_literal: true

require "support/activerecord"
require "support/matchers/run_queries"

load_plugin_code :activerecord_preloads
load_plugin_code :presenter

RSpec.describe Serega::SeregaPlugins::ActiverecordPreloads do
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
