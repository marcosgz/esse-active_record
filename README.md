# Esse ActiveRecord Plugin

This gem is a [esse](https://github.com/marcosgz/esse) plugin for the ActiveRecord ORM. It provides a set of methods to simplify implementation of ActiveRecord models as datasource of esse indexes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'esse-active_record'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install esse-active_record

## Usage

Add the `:active_record` plugin and configure the `collection` with the ActiveRecord model you want to use.

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User
    document # ...
  end
end
```

Using multiple repositories is also possible:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :account do
    collection ::Account
    document # ...
  end

  repository :admin do
    collection ::User.where(admin: true)
    document # ...
  end
end
```

### Collection Scope
It's also possible to specify custom scopes to the repository collection to be used to import data to the index:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User do
      scope :active, -> { where(active: true) }
      scope :role, ->(role) { where(role: role) }
    end
    document # ...
  end
end

# Import data using the scopes
#   > UsersIndex.import(context: { active: true, role: 'admin' })
#
# Streaming data using the scopes
#   > UsersIndex.documents(active: true, role: 'admin').first
```

## Collection Batch Context

Assume that you have a collection of orders and you want to also include the customer data that lives in a external system. To avoid making a request for each order, you can use the `batch_context` to fetch the data in batches and make it available in the document context.

```ruby
class OrdersIndex < Esse::Index
  plugin :active_record

  repository :order do
    collection ::Order do
      batch_context :customers do |orders, **_existing_context|
        # The return value will be available in the document context
        # { customers: <value returned from this block> }
        ExternalSystem::Customer.find_all_by_ids(orders.map(&:customer_id)).index_by(&:id) # => { 1 => <Customer>, 2 => <Customer> }
      end
    end
    document do |order, customers: {}, **_|
      customer = customers[order.customer_id]
      {
        id: order.id,
        customer: {
          id: customer&.id,
          name: customer&.name
        }
      }
    end
  end
end
```

For active record associations, you can define the repository collection by eager loading the associations as usual:

```ruby

class OrdersIndex < Esse::Index
  plugin :active_record

  repository :order do
    collection ::Order.includes(:customer)
    document do |order, **_|
      {
        id: order.id,
        customer: {
          id: order.customer&.id,
          name: order.customer&.name
        }
      }
    end
  end
end
```

### Data Streaming Options

As default the active record support 3 streaming options:
* `batch_size`: the number of documents to be streamed in each batch. Default is 1000;
* `start`: the primary key value to start from, inclusive of the value;
* `finish`: the primary key value to end at, inclusive of the value;

This is useful when you want to import simultaneous data. You can make one process import all records between 1 and 10,000, and another from 10,000 and beyond

```ruby
UsersIndex.import(context: { start: 1, finish: 10000, batch_size: 500 })
```

The default valueof `batch_size` can be also defined in the `collection` configuration:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User, batch_size: 500
    document # ...
  end
end
```

### Indexing Callbacks

The `index_callback` callback can be used to automaitcally index or delete documents after commit on create/update/destroy events.

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user, const: true do
    collection ::User
    document # ...
  end

end

class User < ApplicationRecord
  belongs_to :organization

  # Using a index and repository as argument. Note that the index name is used instead of the
  # of the constant name. it's so because index and model depends on each other should result in
  # circular dependencies issues.
  index_callback 'users_index:user'
  # Using a block to direct a different object to be indexed
  index_callback('organizations') { user.organization } # The `_index` suffix and repo name  is optional on the index name
end
```

Callbacks can also be disabled/enabled globally:

```ruby
Esse::ActiveRecord::Hooks.disable!
Esse::ActiveRecord::Hooks.enable!
Esse::ActiveRecord::Hooks.without_indexing do
  10.times { User.create! }
end
```

or by some specific list of index or index's repository

```ruby
Esse::ActiveRecord::Hooks.disable!(UsersIndex.repo)
Esse::ActiveRecord::Hooks.enable!(UsersIndex.repo)
Esse::ActiveRecord::Hooks.without_indexing(AccountsIndex, UsersIndex.repo) do
  10.times { User.create! }
end
```

or by the model that the callback is configured

```ruby
User.without_indexing do
  10.times { User.create! }
end
User.without_indexing(AccountsIndex) do
  10.times { User.create! }
end
```

### Asynchronous Indexing

If you are using a background job processor like Sidekiq or Faktory, you may be interested in indexing documents asynchronously. For this, you can use the [esse-async_indexing](https://github.com/marcosgz/esse-async_indexing) gem.

Add the `esse-async_indexing` gem to your Gemfile and require the `esse/async_indexing/active_record` file in your application initialization. Make sure to setup the gem configurationg according to the [esse-async_indexing documentation](https://github.com/marcosgz/esse-async_indexing).


```ruby
require 'esse/async_indexing/active_record'
```

Then, you can use the `async_index_callback` or `async_update_lazy_attribute_callback` methods to push the indexing job to the background job processor.

```diff
class City < ApplicationRecord
  include Esse::ActiveRecord::Model
- include Esse::ActiveRecord::Model
+ include Esse::AsyncIndexing::ActiveRecord::Model

  belongs_to :state, optional: true


  async_indexing_callback('geos_index:city') { id }
- index_callback('geos_index:city') { id }
- update_lazy_attribute_callback('geos_index:state', 'cities_count', if: :state_id?) { state_id }
+ async_index_callback('geos_index:city', service_name: :sidekiq) { id }
+ async_update_lazy_attribute_callback('geos_index:state', 'cities_count', if: :state_id?, service_name: :sidekiq) { state_id }
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake none` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/esse-active_record.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
