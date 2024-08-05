if ENV['VERBOSE']
  ActiveRecord::Base.logger = Logger.new($stdout)
end

db_env = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_s
db_path = '/tmp/esse-active_record.db'
db_config = {
  adapter: 'sqlite3',
  database: db_path,
}

if File.exist?(db_path)
  File.delete(db_path)
end

if ::ActiveRecord.gem_version >= Gem::Version.new('6.0.0')
  ActiveRecord::Base.configurations = { db_env => { primary: db_config, secondary: db_config } }
  ActiveRecord::Base.establish_connection(:primary)
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    connects_to database: { writing: :primary, reading: :secondary }
  end
else
  ActiveRecord::Base.configurations = { db_env => db_config }
  ActiveRecord::Base.establish_connection(db_config)
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :animals do |t|
    t.column :name, :string
    t.column :age, :integer
    t.column :type, :string
  end

  create_table :states do |t|
    t.column :name, :string
    t.column :abbr_name, :string
    t.column :iso_country, :string # ISO 3166-1 country/territory code
    t.timestamps
  end

  create_table :counties do |t|
    t.column :name, :string
    t.column :iso_country, :string # ISO 3166-1 country/territory code
    t.column :state_id, :integer
    t.timestamps
  end
end

class Animal < ApplicationRecord
end

class Dog < Animal
end

class Cat < Animal
end

class State < ApplicationRecord
  has_many :counties
end

class County < ApplicationRecord
  belongs_to :state
end

def create_record(klass, **attrs)
  @tables ||= []
  @tables |= [klass.table_name]
  klass.create!(attrs)
end

def build_record(klass, **attrs)
  @tables ||= []
  @tables |= [klass.table_name]
  klass.new(attrs)
end

def clean_db
  (@tables || []).each do |table|
    ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
  end
end
