# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "serega", path: File.join(File.dirname(__FILE__), "..")
end

class AppSerializer < Serega
end

class UserSerializer < AppSerializer
  attribute :id
  attribute :name
  attribute :profile, serializer: "ProfileSerializer"

  presenter do
    def name
      [first_name, last_name].join(" ")
    end
  end
end

class ProfileSerializer < AppSerializer
  attribute :id
  attribute :location
  attribute :followers_count

  presenter do
    def location
      "Gotham City"
    end
  end
end

require "ostruct"
profile = OpenStruct.new(id: 2, followers_count: 999, location: "Earth")
user = OpenStruct.new(id: 1, first_name: "Clark", last_name: "Kent", profile: profile)

response = UserSerializer.new.to_h(user)

require "json"
puts JSON.pretty_generate(response)
