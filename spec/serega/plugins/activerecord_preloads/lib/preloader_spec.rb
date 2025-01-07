# frozen_string_literal: true

require "support/activerecord"

load_plugin_code :activerecord_preloads

RSpec.describe Serega::SeregaPlugins::ActiverecordPreloads do
  describe described_class::Preloader do
    let(:plugin) { Serega::SeregaPlugins::ActiverecordPreloads }

    describe ".handlers" do
      it "returns array of handlers" do
        expect(described_class.handlers).to eq [
          plugin::ActiverecordRelation,
          plugin::ActiverecordObject,
          plugin::ActiverecordArray,
          plugin::ActiverecordEnumerator
        ]
      end
    end

    describe ".preload" do
      it "does nothing when object is nil" do
        preloads = {foo: {}}
        object = nil
        expect { described_class.preload(object, preloads) }.not_to raise_error
      end

      it "does nothing when object is empty array" do
        preloads = {foo: {}}
        object = []
        expect { described_class.preload(object, preloads) }.not_to raise_error
      end

      it "does nothing when preloads are empty" do
        preloads = {}
        object = 123
        expect { described_class.preload(object, preloads) }.not_to raise_error
      end

      it "raises error when provided object does not support preloading" do
        preloads = {foo: {}}

        object = 123
        expect { described_class.preload(object, preloads) }
          .to raise_error Serega::SeregaError, "Can't preload #{preloads.inspect} to #{object.inspect}"
      end

      it "raises error when providing different types of objects", :with_rollback do
        preloads = {posts: {}}

        object = [AR::User.create!, AR::Post.create!]
        expect { described_class.preload(object, preloads) }
          .to raise_error Serega::SeregaError, "Can't preload #{preloads.inspect} to #{object.inspect}"
      end

      it "preloads data to activerecord object", :with_rollback do
        user = AR::User.create!

        result = described_class.preload(user, {posts: {}})

        expect(result).to be user
        expect(user.association(:posts).loaded?).to be true
      end

      it "preloads data to activerecord array", :with_rollback do
        user = AR::User.create!

        users = [user]
        result = described_class.preload(users, {posts: {}})

        expect(result).to be users
        expect(result[0].association(:posts).loaded?).to be true
      end

      it "preloads data to activerecord relation", :with_rollback do
        user = AR::User.create!

        result = described_class.preload(AR::User.where(id: user.id), {posts: {}})

        expect(result).to eq [user]
        expect(result[0].association(:posts).loaded?).to be true
      end

      it "preloads data to loaded activerecord relation", :with_rollback do
        user = AR::User.create!

        result = described_class.preload(AR::User.where(id: user.id).load, {posts: {}})

        expect(result).to eq [user]
        expect(result[0].association(:posts).loaded?).to be true
      end

      it "preloads data to enumerator", :with_rollback do
        users = [AR::User.create!, AR::User.create!].each

        result = described_class.preload(users, {posts: {}})

        expect(result).to be users
        expect(result.first.association(:posts).loaded?).to be true
      end
    end
  end
end
