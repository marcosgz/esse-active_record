# Usage Guide

## Installation

```ruby
# Gemfile
gem 'esse'
gem 'esse-active_record'
```

```bash
bundle install
```

Enable the plugin on any index:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record
end
```

## The `collection` DSL

Inside a repository, pass an ActiveRecord model (or relation) to `collection`:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User
    document { |u, **| { _id: u.id, name: u.name } }
  end
end
```

Options:

| Option | Default | Description |
|--------|---------|-------------|
| `batch_size` | `1000` | Records per batch (`find_in_batches`) |
| `connect_with` | — | `{ role: :reading }` / `{ shard: :primary }` to use connection switching |

```ruby
repository :user do
  collection ::User, batch_size: 500, connect_with: { role: :reading }
  document { |u, **| { _id: u.id, name: u.name } }
end
```

## Scopes

Define scopes to filter or shape the data at import time:

```ruby
repository :user do
  collection ::User do
    scope :active, -> { where(active: true) }
    scope :role,   ->(role) { where(role: role) }
  end

  document { |u, **| { _id: u.id, name: u.name, role: u.role } }
end

# Apply at import:
UsersIndex.import(context: { active: true, role: 'admin' })
```

Scopes are composable; arguments are passed positionally to the proc.

## Batch context (avoid N+1)

When serialization needs data from a related source, fetch it once per batch:

```ruby
repository :order do
  collection ::Order do
    batch_context :customers do |orders, **|
      Customer.where(id: orders.map(&:customer_id)).index_by(&:id)
    end
  end

  document do |order, customers: {}, **|
    customer = customers[order.customer_id]
    { _id: order.id, customer_name: customer&.name }
  end
end
```

The context is merged into each batch and forwarded to `document`.

## Eager loading associations

Just use `.includes`/`.eager_load` directly in the collection:

```ruby
repository :order do
  collection ::Order.includes(:customer, :line_items)
  document do |order, **|
    { _id: order.id, customer: order.customer.name, line_count: order.line_items.size }
  end
end
```

## Automatic callbacks

Include `Esse::ActiveRecord::Model` and declare `index_callback`:

```ruby
class User < ApplicationRecord
  include Esse::ActiveRecord::Model
  index_callback 'users_index:user'
end
```

The reference format is `'index_name:repo_name'`. These all resolve to `UsersIndex.repo(:user)`:

- `'users'`
- `'users_index'`
- `'users_index:user'`
- `'UsersIndex'`
- `'UsersIndex::User'`
- `'foo/v1/users_index:user'` (namespaced)

Options:

```ruby
index_callback 'users_index:user',
  on:     %i[create update],   # default: [:create, :update, :destroy]
  with:   :update,             # use ES update API (partial); falls back to index() on NotFound
  if:     :active?,            # conditions work like ActiveRecord
  unless: :deleted?
```

### Index an associated record instead

Return the target object from the block:

```ruby
class City < ApplicationRecord
  belongs_to :state
  include Esse::ActiveRecord::Model

  # Re-index the state when a city changes
  index_callback('geos_index:state') { state }
end
```

### Update a lazy attribute

When a child record changes, update just one field on the parent document:

```ruby
class Comment < ApplicationRecord
  belongs_to :post
  include Esse::ActiveRecord::Model

  update_lazy_attribute_callback('posts_index:post', 'comments_count') { post_id }
end
```

The callback calls `repo.update_documents_attribute(:comments_count, [post_id], ...)`.

## Disabling callbacks

You will often want to turn callbacks off during bulk migrations, seeding, or tests.

### Per-block

```ruby
Esse::ActiveRecord::Hooks.without_indexing do
  10_000.times { User.create!(...) }
end
```

### For specific repos

```ruby
Esse::ActiveRecord::Hooks.without_indexing(UsersIndex, AccountsIndex) do
  migrate_users!
end
```

### Per-model

```ruby
User.without_indexing { User.create!(...) }
User.without_indexing(UsersIndex) { User.create!(...) }
```

### Globally

```ruby
Esse::ActiveRecord::Hooks.disable!
# ... bulk operation ...
Esse::ActiveRecord::Hooks.enable!
```

## Streaming by ID range

Useful for parallel batch processing across workers:

```ruby
UsersIndex.import(context: { start: 1,     finish: 5000,  batch_size: 500 })
UsersIndex.import(context: { start: 5001,  finish: 10000, batch_size: 500 })
```

`start` and `finish` are primary-key bounds (inclusive on both ends).

## Async indexing

The companion [esse-async_indexing](../../esse-async_indexing/docs/README.md) gem adds Sidekiq/Faktory-backed versions of all callbacks:

```ruby
require 'esse/async_indexing/active_record'

class City < ApplicationRecord
  include Esse::AsyncIndexing::ActiveRecord::Model

  async_index_callback('geos_index:city', service_name: :sidekiq) { id }
  async_update_lazy_attribute_callback(
    'states_index:state', 'cities_count',
    if: :state_id?,
    service_name: :sidekiq
  ) { state_id }
end
```

## Patterns

### Separate repositories on one index

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :account do
    collection ::Account
    document { |a, **| { _id: a.id, name: a.name, type: 'account' } }
  end

  repository :admin do
    collection ::User.where(admin: true)
    document { |u, **| { _id: u.id, name: u.name, type: 'admin' } }
  end
end
```

### Multi-database with connection switching

```ruby
repository :user do
  collection ::User, connect_with: { role: :reading }
  # or inside the block:
  collection ::User do
    connected_to(role: :reading)
  end
  document { ... }
end
```

### Disabling callbacks during bulk import

```ruby
Esse::ActiveRecord::Hooks.without_indexing do
  seed_data!
end

# Now index them all
UsersIndex.import
```
