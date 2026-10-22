# Hash Records

The `:hash_access` attribute option reads values from Hash keys, for records
loaded as Hashes from JSON, Redis or raw SQL.

```ruby
class UserSerializer < Serega
  attribute :name, hash_access: true        # record[:name]
  attribute :email, hash_access: :string    # record["email"]
  attribute :full_name, method: :name, hash_access: true # record[:name]
end

UserSerializer.to_h({:name => "Bruce", "email" => "bruce@wayne.com"})
# => {name: "Bruce", email: "bruce@wayne.com", full_name: "Bruce"}
```

Modes:

- `:symbol` reads `record[:name]`;
- `:string` reads `record["name"]`;
- `true` uses `config.hash_access.default_mode`, `:symbol` by default.

Records can be any objects with `#[]`, `#fetch` and `#key?`.

## Missing keys

A missing key raises `KeyError`. `allow_missing_key: true` serializes `nil`
instead:

```ruby
attribute :age, hash_access: true
# => KeyError: key not found: :age

attribute :age, hash_access: {allow_missing_key: true}
attribute :age, hash_access: {mode: :string, allow_missing_key: true}
# => {age: nil}
```

## Defaults

```ruby
class AppSerializer < Serega
  config.hash_access.default_mode = :string           # mode of `hash_access: true`
  config.hash_access.default_allow_missing_key = true # nil for missing keys
end
```

## Delegates

Delegates choose hash access per step: `:to_hash_access` reads the associated
record, `:hash_access` reads the final value. Both accept the same values as
the `:hash_access` attribute option.

```ruby
attribute :city, delegate: {to: :address, to_hash_access: true}                    # record[:address].city
attribute :city, delegate: {to: :address, hash_access: true}                       # record.address[:city]
attribute :city, delegate: {to: :address, to_hash_access: true, hash_access: true} # record[:address][:city]

# record["address"][:city], nil when record has no "address"
attribute :city, delegate: {
  to: :address,
  allow_nil: true,
  to_hash_access: {mode: :string, allow_missing_key: true},
  hash_access: :symbol
}
```

The `:hash_access` attribute option can not be combined with `:delegate`.

## Relations

```ruby
class AddressSerializer < Serega
  attribute :city, hash_access: true
end

class UserSerializer < Serega
  attribute :address, hash_access: true, serializer: AddressSerializer
end

UserSerializer.to_h({address: {city: "Gotham"}}) # => {address: {city: "Gotham"}}
```
