# API Reference

## `Esse::Plugins::ActiveRecord`

The plugin module. Registered via:

```ruby
class MyIndex < Esse::Index
  plugin :active_record
end
```

### Repository class methods

#### `collection(model, **opts, &block)`

Replaces the default `collection` DSL. Accepts a class inheriting from `::ActiveRecord::Base` or an `::ActiveRecord::Relation`.

| Argument | Description |
|----------|-------------|
| `model` | AR class or relation |
| `batch_size:` | Records per batch (default `1000`) |
| `connect_with:` | Hash of `{role:, shard:}` for connection switching |
| `&block` | Block evaluated in the collection class scope — use for `scope` / `batch_context` / `connected_to` |

Returns an `Esse::ActiveRecord::Collection` subclass.

#### `dataset(**params)`

Returns the current filtered `ActiveRecord::Relation` (applies scopes).

---

## `Esse::ActiveRecord::Collection`

Base class for collections built from ActiveRecord models. Subclasses are created automatically by the `collection` DSL.

### Class-level DSL

#### `scope(name, proc = nil, override: false, &block)`

Define a named scope.

```ruby
collection ::User do
  scope :active, -> { where(active: true) }
  scope :role,   ->(role) { where(role: role) }
end
```

#### `batch_context(name, proc = nil, override: false, &block)`

Define a batch enrichment fetcher — invoked once per batch with `(records, **ctx)`.

```ruby
collection ::Order do
  batch_context :customers do |orders, **|
    Customer.where(id: orders.map(&:customer_id)).index_by(&:id)
  end
end
```

#### `connected_to(**kwargs)`

Set database role/shard:

```ruby
collection ::User do
  connected_to(role: :reading)
end
```

### Instance methods

| Method | Description |
|--------|-------------|
| `each { |rows, **ctx| }` | Iterate batches with applied scopes + batch contexts |
| `each_batch_ids { |ids| }` | Iterate ID batches (skips eager loads) |
| `count` / `size` | Total rows after scopes applied |
| `dataset(**kwargs)` | Return filtered `ActiveRecord::Relation` |

Constructor:

```ruby
CollectionClass.new(start: 1, finish: 10_000, batch_size: 500, **scope_args)
```

| Param | Description |
|-------|-------------|
| `start` | Primary key lower bound (inclusive) |
| `finish` | Primary key upper bound (inclusive) |
| `batch_size` | Overrides class default |
| `**params` | Scope arguments and extra where-conditions |

---

## `Esse::ActiveRecord::Model`

Mixin for ActiveRecord models. `include` it to register callbacks.

### `index_callback(reference, on: [...], with: nil, **opts, &block)`

Registers an `after_commit` callback that indexes the model into a repository.

| Param | Description |
|-------|-------------|
| `reference` | `'index_name'` or `'index_name:repo_name'` (or class-constant form) |
| `on:` | Which events — any subset of `[:create, :update, :destroy]`. Default: all three. |
| `with:` | `:update` for partial updates, `nil` (default) for full reindex |
| `if:` / `unless:` | Same semantics as AR `after_commit` |
| `&block` | Optional — return the object to index (default: `self`) |

Raises `ArgumentError` if the same repo already has a callback registered.

### `update_lazy_attribute_callback(reference, attribute, on: [...], **opts, &block)`

Registers a callback that calls `repo.update_documents_attribute(attribute, ids, opts)` on commit.

```ruby
update_lazy_attribute_callback('posts_index:post', 'comments_count') { post_id }
```

The block returns the ID (or array of IDs) of the document to update.

### `without_indexing(*repos, &block)`

Temporarily disables callbacks for this model class.

```ruby
User.without_indexing { User.create!(...) }
User.without_indexing(UsersIndex) { User.create!(...) }
```

### `esse_callbacks`

Returns a frozen hash of registered callbacks:

```ruby
User.esse_callbacks
# => { 'users_index:user' => { create_indexing: [klass, opts, block], ... } }
```

---

## `Esse::ActiveRecord::Hooks`

Global state for enabling/disabling indexing callbacks. Uses [esse-hooks](../../esse-hooks/docs/README.md) under the hood.

### `disable!` / `enable!`

Toggle callbacks globally:

```ruby
Esse::ActiveRecord::Hooks.disable!
# ... bulk work ...
Esse::ActiveRecord::Hooks.enable!
```

### `without_indexing(*repos, &block)`

Scoped disable, auto-restores state after the block.

```ruby
Esse::ActiveRecord::Hooks.without_indexing do
  ...
end

Esse::ActiveRecord::Hooks.without_indexing(UsersIndex.repo(:user)) do
  ...
end
```

### `with_indexing(*repos, &block)`

Opposite — forces enabling in a scope.

### `enabled?(repo = nil)` / `disabled?(repo = nil)`

Check global or per-repo status.

### `resolve_index_repository(reference)`

Resolve a string reference to a repository instance:

```ruby
Esse::ActiveRecord::Hooks.resolve_index_repository('users_index:user')
# => UsersIndex.repo(:user)
```

Supported forms:

- `'users'`
- `'users_index'`
- `'users_index:user'`
- `'UsersIndex'`
- `'UsersIndex::User'`
- `'foo/v1/users_index/user'` (namespaced)

### `register_model(model_class)` / `models`

Used internally by `index_callback` to track model classes that have callbacks.

---

## Built-in callback classes

Registered in `Esse::ActiveRecord::Callbacks`. All inherit from `Esse::ActiveRecord::Callback`.

| Callback | Registered as | Behavior |
|----------|---------------|----------|
| `IndexingOnCreate` | `:create_indexing` | Calls `repo.index(doc)` on create |
| `IndexingOnUpdate` | `:update_indexing` | Calls `repo.update(doc)` or `repo.index(doc)` (depending on `with:`). If routing changed, deletes the previous document at the old routing. |
| `IndexingOnDestroy` | `:destroy_indexing` | Calls `repo.delete(doc)` on destroy. Silently handles `NotFoundError`. |
| `UpdateLazyAttribute` | `:create_update_lazy_attribute`, `:update_update_lazy_attribute`, `:destroy_update_lazy_attribute` | Calls `repo.update_documents_attribute(attribute, ids, opts)` |

### Custom callbacks

Subclass `Esse::ActiveRecord::Callback`:

```ruby
class MyCallback < Esse::ActiveRecord::Callback
  def call(model)
    # ...
  end
end

Esse::ActiveRecord::Callbacks.register_callback(:my_thing, :create, MyCallback)
```

Then reference it through your own DSL — use the built-in mechanism as a template.

---

## Deprecated methods

| Deprecated | Use instead |
|------------|-------------|
| `index_callbacks` | `index_callback` |
| `esse_index_repos` | `esse_callbacks` |
