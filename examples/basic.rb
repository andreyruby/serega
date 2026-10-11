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
  attribute :name, value: proc { |user| [user.first_name, user.last_name].join(" ") }

  attribute :profile, serializer: "ProfileSerializer"
  attribute :roles, serializer: "RoleSerializer"
end

class ProfileSerializer < AppSerializer
  attribute :id
  attribute :location, value: proc { |profile| profile.location || "Gotham City" }
  attribute :followers_count
end

class RoleSerializer < AppSerializer
  attribute :id
  attribute :name
end

require "ostruct"
role1 = OpenStruct.new(id: 4, name: "superhero")
role2 = OpenStruct.new(id: 3, name: "reporter")
profile = OpenStruct.new(id: 2, followers_count: 999, location: nil)
user = OpenStruct.new(id: 1, first_name: "Clark", last_name: "Kent", profile: profile, roles: [role1, role2])

response = UserSerializer.new.to_h(user)

require "json"
puts JSON.pretty_generate(response)
