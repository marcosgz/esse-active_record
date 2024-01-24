if ENV['VERBOSE']
  ActiveRecord::Base.logger = Logger.new($stdout)
end
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

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

class Animal < ActiveRecord::Base
end

class Dog < Animal
end

class Cat < Animal
end

class State < ActiveRecord::Base
  has_many :counties
end

class County < ActiveRecord::Base
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
