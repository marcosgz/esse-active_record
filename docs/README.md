# esse-active_record

ActiveRecord integration for [Esse](../../esse/docs/README.md). Provides:

- `collection Model` DSL for repositories, backed by `find_in_batches`.
- Automatic `after_commit` callbacks to index, update, or delete documents.
- Scoping and per-batch context fetching for efficient serialization.
- Hook-based control to disable indexing globally, per-repository, or per-model.
- Support for partial `:update` and lazy attribute denormalization.

## Contents

- [Usage guide](usage.md)
- [API reference](api.md)

## Quick start

```ruby
# Gemfile
gem 'esse-active_record'
```

```ruby
# app/indices/users_index.rb
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User, batch_size: 500 do
      scope :active, -> { where(active: true) }
    end

    document do |user, **|
      { _id: user.id, name: user.name, email: user.email }
    end
  end
end
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Esse::ActiveRecord::Model
  index_callback 'users_index:user'
end
```

Every `User.create!`, `update!`, and `destroy` now syncs to Elasticsearch automatically.

## Version

- Version: **0.3.9**
- Ruby: `>= 2.4.0`
- Depends on: `esse >= 0.3.0`, `esse-hooks`, `activerecord >= 4.2`

## License

MIT.
