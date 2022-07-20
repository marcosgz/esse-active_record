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

Add the `:active_record` plugin and configure the `repository` or the `collection` with the ActiveRecord model you want to use.

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User
    serializer # ...
  end
end
```

Using multiple repositories is also possible:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :account do
    collection ::Account
    serializer # ...
  end

  repository :admin do
    collection ::User.where(admin: true)
    serializer # ...
  end
end
```

### Repository Scope
It's also possible to specify custom scopes to the repository collection to be used to import data to the index:

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user do
    collection ::User do
      scope :active, -> { where(active: true) }
      scope :role, ->(role) { where(role: role) }
    end
    serializer # ...
  end
end

# Import data using the scopes
#   > UsersIndex.elasticsearch.import(context: { active: true, role: 'admin' })
# 
# Streaming data using the scopes
#   > UsersIndex.documents(active: true, role: 'admin').first
```

### Indexing Callbacks

The `index_callbacks` callback can be used to automaitcally index or delete documents after commit on create/update/destroy events.

```ruby
class UsersIndex < Esse::Index
  plugin :active_record

  repository :user, const: true do
    collection ::User
    serializer # ...
  end

end

class User < ApplicationRecord
  belongs_to :organization

  # Using a index repository as argument
  index_callbacks AccountsIndex::User # Or UsersIndex.repo(:user) if repository is defined with `const: false'
  # Using a index as argument. The default repository will be used. In case of multiple repositories, one exception will be raised.
  index_callbacks UsersIndex 
  # Using a block to direct a different object to be indexed
  index_callbacks(OrganizationsIndex) { user.organization }
end
```

Callbacks can also be disabled/enabled globally:

```ruby
Esse::ActiveRecord::Hoods.disable!
Esse::ActiveRecord::Hoods.enable!
Esse::ActiveRecord::Hoods.without_indexing do
  10.times { User.create! }
end
```

or by some specific list of index or index's repository

```ruby
Esse::ActiveRecord::Hoods.disable!(UsersIndex.repo)
Esse::ActiveRecord::Hoods.enable!(UsersIndex.repo)
Esse::ActiveRecord::Hoods.without_indexing(AccountsIndex UsersIndex.repo, ) do
  10.times { User.create! }
end
```

or by the model that the hook is configured

```ruby
User.without_indexing do
  10.times { User.create! }
end
User.without_indexing(AccountsIndex) do
  10.times { User.create! }
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake none` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/esse-active_record.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
