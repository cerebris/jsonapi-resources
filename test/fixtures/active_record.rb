require 'active_record'
require 'json/api/resource_controller'
require 'json/api/resource'
require 'json/api/exceptions'
require 'rails'
require 'rails/all'

### DATABASE
ActiveRecord::Schema.define do
  create_table :people, force: true do |t|
    t.string     :name
    t.string     :email
    t.datetime   :date_joined
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.string     :title
    t.text       :body
    t.integer    :author_id
    t.belongs_to :section, index: true
    t.timestamps
  end

  create_table :comments, force: true do |t|
    t.text       :body
    t.belongs_to :post, index: true
    t.integer    :author_id
    t.timestamps
  end

  create_table :tags, force: true do |t|
    t.string :name
  end

  create_table :sections, force: true do |t|
    t.string :name
  end

  create_table :posts_tags, force: true do |t|
    t.references :post, :tag, index: true
  end

  create_table :comments_tags, force: true do |t|
    t.references :comment, :tag, index: true
  end

  create_table :currencies, id: false, force: true do |t|
    t.string :code, limit: 3, null: false
    t.string :name
    t.timestamps
  end
  add_index :currencies, :code, unique: true

  create_table :expense_entries, force: true do |t|
    t.string :currency_code, limit: 3, null: false
    t.integer :employee_id, null: false
    t.decimal :cost, precision: 12, scale: 4, null: false
    t.date :transaction_date
  end

  create_table :planets, force: true do |t|
    t.string :name
    t.string :description
  end

  create_table :moons, force: true do |t|
    t.string  :name
    t.string  :description
    t.integer :planet_id
  end
end

### MODELS
class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception

  ### Validations
  validates :name, presence: true
  validates :date_joined, presence: true
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  has_many :comments
  has_and_belongs_to_many :tags, join_table: :posts_tags
  belongs_to :section
end

class Comment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :post
  has_and_belongs_to_many :tags, join_table: :comments_tags
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts, join_table: :posts_tags
end

class Section < ActiveRecord::Base
end

class Currency < ActiveRecord::Base
  self.primary_key = :code
  has_many :expense_entries, foreign_key: 'currency_code'
end

class ExpenseEntry < ActiveRecord::Base
  belongs_to :employee, class_name: 'Person', foreign_key: 'employee_id'
  belongs_to :currency, class_name: 'Currency', foreign_key: 'currency_code'
end

class Planet < ActiveRecord::Base
  has_many :moons
end

class Moon < ActiveRecord::Base
  belongs_to :planet
end

class Breed

  def initialize(id = nil, name = nil)
    if id.nil?
      @id = $breed_data.new_id
      $breed_data.add(self)
    else
      @id = id
    end
    @name = name
  end

  attr_accessor :id, :name

  def destroy
    $breed_data.remove(@id)
  end

  def save!
  end
end

class BreedData
  def initialize
    @breeds = {}
  end

  def breeds
    @breeds
  end

  def new_id
    @breeds.keys.max + 1
  end

  def add(breed)
    @breeds[breed.id] = breed
  end

  def remove(id)
    @breeds.delete(id)
  end

end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))

### CONTROLLERS
class AuthorController < JSON::API::ResourceController

end

class PeopleController < JSON::API::ResourceController

end

class PostsController < JSON::API::ResourceController
end

class TagsController < JSON::API::ResourceController
end

class CurrenciesController < JSON::API::ResourceController
end

class ExpenseEntriesController < JSON::API::ResourceController
end

class BreedsController < JSON::API::ResourceController
end

### RESOURCES
class PersonResource < JSON::API::Resource
  attributes :id, :name, :email, :date_joined
  has_many :comments
  has_many :posts

  filter :name

  def self.verify_custom_filter(filter, values)
    case filter
      when :name
        values.each do |value|
          if value.length < 3
            raise JSON::API::Exceptions::InvalidFilterValue.new(filter, value)
          end
        end
    end
    return filter, values
  end
end

class AuthorResource < JSON::API::Resource
  attributes :id, :name, :email
  model_name 'Person'
  has_many :posts

  filter :name

  def self.find(attrs, options = {})
    resources = []

    attrs[:filters].each do |attr, filter|
      _model_class.where("\"#{attr}\" LIKE \"%#{filter[0]}%\"").each do |object|
        resources.push self.new(object)
      end
    end
    return resources
  end

  def fetchable(keys, options = {})
    if (@object.id % 2) == 1
      super(keys - [:email])
    else
      super(keys)
    end
  end
end

class CommentResource < JSON::API::Resource
  attributes :id, :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags
end

class TagResource < JSON::API::Resource
  attributes :id, :name

  has_many :posts
end

class SectionResource < JSON::API::Resource
  attributes 'name'
end

class PostResource < JSON::API::Resource
  attribute :id
  attribute :title
  attribute :body
  attribute :subject

  has_one :author, class_name: 'Person'
  has_one :section
  has_many :tags, treat_as_set: true
  has_many :comments, treat_as_set: false
  def subject
    @object.title
  end

  filters :title, :author
  filter :id

  def self.updateable(keys, options = {})
    super(keys - [:author, :subject])
  end

  def self.createable(keys, options = {})
    super(keys - [:subject])
  end

  def self.verify_custom_filter(filter, values)
    case filter
      when :id
        values.each do |id|
          verify_id(id)
        end
    end
    return filter, values
  end

  def self.is_num?(str)
    begin
      !!Integer(str)
    rescue ArgumentError, TypeError
      false
    end
  end

  def self.verify_id(id)
    raise JSON::API::Exceptions::InvalidFieldValue.new(:id, id) unless is_num?(id)
    raise JSON::API::Exceptions::RecordNotFound.new(id) unless find_by_key(id)
    return id
  end
end

class CurrencyResource < JSON::API::Resource
  key :code
  attributes :code, :name

  has_many :expense_entries
end

class ExpenseEntryResource < JSON::API::Resource
  attributes :id, :cost, :transaction_date

  has_one :currency, class_name: 'Currency', key: 'currency_code'
  has_one :employee
end

class BreedResource < JSON::API::Resource
  attributes :id, :name

  def self.find(attrs, options = {})
    breeds = []
    $breed_data.breeds.values.each do |breed|
      breeds.push(BreedResource.new(breed))
    end
    breeds
  end

  def self.find_by_key(id, options = {})
    BreedResource.new($breed_data.breeds[id.to_i])
  end
end

class PlanetResource < JSON::API::Resource
  attribute :id
  attribute :name
  attribute :description

  has_many :moons
end

class MoonResource < JSON::API::Resource
  attribute :id
  attribute :name
  attribute :description

  has_one :planet
end


### DATA
javascript = Section.create(name: 'javascript')

a = Person.create(name: 'Joe Author',
                 email: 'joe@xyz.fake',
                 date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'))

b = Person.create(name: 'Fred Reader',
                 email: 'fred@xyz.fake',
                 date_joined: DateTime.parse('2013-10-31 20:25:00 UTC +00:00'))

c = Person.create(name: 'Lazy Author',
                  email: 'lazy@xyz.fake',
                  date_joined: DateTime.parse('2013-10-31 21:25:00 UTC +00:00'))

d = Person.create(name: 'Tag Crazy Author',
                  email: 'taggy@xyz.fake',
                  date_joined: DateTime.parse('2013-11-30 4:20:00 UTC +00:00'))

Post.create(title: 'New post',
              body:  'A body!!!',
              author_id: a.id).tap do |post|

  short_tag = post.tags.create(name: 'short')
  whiny_tag = post.tags.create(name: 'whiny')
  grumpy_tag = post.tags.create(name: 'grumpy')
  happy_tag = Tag.create(name: 'happy')

  post.comments.create(body: 'what a dumb post', author_id: a.id, post_id: post.id).tap do |comment|
    comment.tags.concat whiny_tag, short_tag
  end

  post.comments.create(body: 'i liked it', author_id: b.id, post_id: post.id).tap do |comment|
    comment.tags.concat happy_tag, short_tag
  end
end

Post.create(title: 'AMS Solves your serialization wows!',
              body:  'Use AMS',
              author_id: a.id,
              section: Section.create(name: 'ruby')).tap do |post|

  ams_tag = post.tags.create(name: 'AMS')

  post.comments.create(body: 'Thanks man. Great post. But what is AMS?', author_id: b.id, post_id: post.id).tap do |comment|
    comment.tags.concat ams_tag
  end
end

# id:3
Post.create(title: 'Update This Later',
            body:  'AAAA',
            author_id: c.id)

# id:4
Post.create(title: 'Delete This Later - Single',
            body:  'AAAA',
            author_id: c.id)

# id:5
Post.create(title: 'Delete This Later - Multiple1',
            body:  'AAAA',
            author_id: c.id)

# id:6
Post.create(title: 'Delete This Later - Multiple2',
            body:  'AAAA',
            author_id: c.id)

# id:7
Post.create(title: 'Delete This Later - Single2',
            body:  'AAAA',
            author_id: c.id)

# id:8
Post.create(title: 'Delete This Later - Multiple2-1',
            body:  'AAAA',
            author_id: c.id)

# id:9
Post.create(title: 'Delete This Later - Multiple2-2',
            body:  'AAAA',
            author_id: c.id)

# id:9
Post.create(title: 'Update This Later - Multiple',
            body:  'AAAA',
            author_id: c.id)

Currency.create(code: 'USD', name: 'United States Dollar')
Currency.create(code: 'EUR', name: 'Euro Member Countries')

ExpenseEntry.create(currency_code: 'USD',
               employee_id: c.id,
               cost: '12.05',
               transaction_date: DateTime.parse('2014-04-15 12:13:14 UTC +00:00'))

ExpenseEntry.create(currency_code: 'USD',
               employee_id: c.id,
               cost: '12.06',
               transaction_date: DateTime.parse('2014-04-15 12:13:15 UTC +00:00'))

silly_tag = Tag.create(name: 'silly')
sleepy_tag = Tag.create(name: 'sleepy')
goofy_tag = Tag.create(name: 'goofy')
wacky_tag = Tag.create(name: 'wacky')

Post.create(title: 'Tagged up post 1',
            body:  'AAAA',
            author_id: d.id,
            tag_ids: [6,7,8,9]
            )

Post.create(title: 'Tagged up post 2',
            body:  'BBBB',
            author_id: d.id,
            tag_ids: [6,7,8,9]
)

saturn = Planet.create(name: 'Satern', description: 'Saturn is the sixth planet from the Sun and the second largest planet in the Solar System, after Jupiter.')
titan = Moon.create(name:'Titan', description: 'Best known of the Saturn moons.', planet_id: saturn.id)
pluto = Planet.create(name: 'Pluto', description: 'Pluto is the smallest planet.')
uranus = Planet.create(name: 'Uranus', description: 'Insert adolescent jokes here.')
jupiter = Planet.create(name: 'Jupiter', description: 'A gas giant.')
