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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake none` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/esse-active_record.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
