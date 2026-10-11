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
  attribute :name
  attribute :email, hide: true

  attribute :avatar, serializer: "AvatarSerializer"
  attribute :profile, serializer: "ProfileSerializer", hide: true
end

class AvatarSerializer < AppSerializer
  attribute :url
  attribute :url_2x
end

class ProfileSerializer < AppSerializer
  attribute :desc
  attribute :location, hide: true
end

require "ostruct"
avatar = OpenStruct.new(id: 3, url: "http://example.com/url", url_2x: "http://example.com/url_2x")
profile = OpenStruct.new(id: 2, desc: "...", location: "Earth")
user = OpenStruct.new(id: 1, name: "batman", avatar: avatar, email: "janedoe@example.com", profile: profile)

require "json"

puts "UserSerializer.new(except: [:name, avatar: :url_2x]).to_h(user)"
puts JSON.pretty_generate(UserSerializer.new(except: [:name, avatar: :url_2x]).to_h(user))

puts

puts "UserSerializer.new(with: [:email, profile: :location]).to_h(user)"
puts JSON.pretty_generate(UserSerializer.new(with: [:email, profile: :location]).to_h(user))

puts

puts "UserSerializer.new(only: { profile: :location }).to_h(user)"
puts JSON.pretty_generate(UserSerializer.new(only: {profile: :location}).to_h(user))
