require 'active_record'
require 'jsonapi-resources'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'preferences'
  inflect.irregular 'numero_telefone', 'numeros_telefone'
end

### DATABASE
ActiveRecord::Schema.define do
  create_table :people, force: true do |t|
    t.string     :name
    t.string     :email
    t.datetime   :date_joined
    t.belongs_to :preferences
    t.integer :hair_cut_id, index: true
    t.timestamps null: false
  end

  create_table :posts, force: true do |t|
    t.string     :title
    t.text       :body
    t.integer    :author_id
    t.belongs_to :section, index: true
    t.timestamps null: false
  end

  create_table :comments, force: true do |t|
    t.text       :body
    t.belongs_to :post, index: true
    t.integer    :author_id
    t.timestamps null: false
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
  add_index :posts_tags, [:post_id, :tag_id], unique: true

  create_table :comments_tags, force: true do |t|
    t.references :comment, :tag, index: true
  end

  create_table :iso_currencies, id: false, force: true do |t|
    t.string :code, limit: 3, null: false
    t.string :name
    t.string :country_name
    t.string :minor_unit
    t.timestamps null: false
  end
  add_index :iso_currencies, :code, unique: true

  create_table :expense_entries, force: true do |t|
    t.string :currency_code, limit: 3, null: false
    t.integer :employee_id, null: false
    t.decimal :cost, precision: 12, scale: 4, null: false
    t.date :transaction_date
  end

  create_table :planets, force: true do |t|
    t.string :name
    t.string :description
    t.integer :planet_type_id
  end

  create_table :planets_tags, force: true do |t|
    t.references :planet, :tag, index: true
  end
  add_index :planets_tags, [:planet_id, :tag_id], unique: true

  create_table :planet_types, force: true do |t|
    t.string :name
  end

  create_table :moons, force: true do |t|
    t.string  :name
    t.string  :description
    t.integer :planet_id
  end

  create_table :preferences, force: true do |t|
    t.integer :person_id
    t.boolean :advanced_mode, default: false
  end

  create_table :facts, force: true do |t|
    t.integer  :person_id
    t.string   :spouse_name
    t.text     :bio
    t.float    :quality_rating
    t.decimal  :salary, :precision => 12, :scale => 2
    t.datetime :date_time_joined
    t.date     :birthday
    t.time     :bedtime
    t.binary   :photo, limit: 1.kilobyte
    t.boolean  :cool
  end

  create_table :books, force: true do |t|
    t.string :title
    t.string :isbn
  end

  create_table :book_comments, force: true do |t|
    t.text       :body
    t.belongs_to :book, index: true
    t.integer    :author_id
    t.timestamps null: false
  end

  create_table :customers, force: true do |t|
    t.string   :name
  end

  create_table :purchase_orders, force: true do |t|
    t.date     :order_date
    t.date     :requested_delivery_date
    t.date     :delivery_date
    t.integer  :customer_id
    t.string   :delivery_name
    t.string   :delivery_address_1
    t.string   :delivery_address_2
    t.string   :delivery_city
    t.string   :delivery_state
    t.string   :delivery_postal_code
    t.float    :delivery_fee
    t.float    :tax
    t.float    :total
    t.timestamps null: false
  end

  create_table :order_flags, force: true do |t|
    t.string :name
  end

  create_table :purchase_orders_order_flags, force: true do |t|
    t.references :purchase_order, :order_flag, index: true
  end
  add_index :purchase_orders_order_flags, [:purchase_order_id, :order_flag_id], unique: true, name: "po_flags_idx"

  create_table :line_items, force: true do |t|
    t.integer  :purchase_order_id
    t.string   :part_number
    t.string   :quantity
    t.float    :item_cost
    t.timestamps null: false
  end

  create_table :hair_cuts, force: true do |t|
    t.string :style
  end

  create_table :numeros_telefone, force: true do |t|
    t.string   :numero_telefone
    t.timestamps null: false
  end
end

### MODELS
class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception
  belongs_to :preferences
  belongs_to :hair_cut

  ### Validations
  validates :name, presence: true
  validates :date_joined, presence: true
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :writer, class_name: 'Person', foreign_key: 'author_id'
  has_many :comments
  has_and_belongs_to_many :tags, join_table: :posts_tags
  belongs_to :section

  validates :author, presence: true
  validates :title, length: { maximum: 35 }
end

class Comment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :post
  has_and_belongs_to_many :tags, join_table: :comments_tags
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts, join_table: :posts_tags
  has_and_belongs_to_many :planets, join_table: :planets_tags
end

class Section < ActiveRecord::Base
end

class IsoCurrency < ActiveRecord::Base
  self.primary_key = :code
  # has_many :expense_entries, foreign_key: 'currency_code'
end

class ExpenseEntry < ActiveRecord::Base
  belongs_to :employee, class_name: 'Person', foreign_key: 'employee_id'
  belongs_to :iso_currency, foreign_key: 'currency_code'
end

class Planet < ActiveRecord::Base
  has_many :moons
  belongs_to :planet_type

  has_and_belongs_to_many :tags, join_table: :planets_tags
end

class PlanetType < ActiveRecord::Base
  has_many :planets
end

class Moon < ActiveRecord::Base
  belongs_to :planet
end

class Preferences < ActiveRecord::Base
  has_one :author, class_name: 'Person'
  has_many :friends, class_name: 'Person'
end

class Fact < ActiveRecord::Base
end

class Like < ActiveRecord::Base
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
    @errors = ActiveModel::Errors.new(self)
  end

  attr_accessor :id, :name

  def destroy
    $breed_data.remove(@id)
  end

  def save
    true
  end

  def valid?
    @errors.clear
    if name.is_a?(String) && name.length > 0
      return true
    else
      @errors.set(:name, ["can't be blank"])
      return false
    end
  end

  def errors
    @errors
  end
end

class Book < ActiveRecord::Base
  has_many :book_comments
end

class BookComment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :book
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

class CustomerOrder < ActiveRecord::Base
  has_many :purchase_orders
end

class PurchaseOrder < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items

  has_and_belongs_to_many :order_flags, join_table: :purchase_orders_order_flags
end

class OrderFlag < ActiveRecord::Base
  has_and_belongs_to_many :purchase_orders, join_table: :purchase_orders_order_flags
end

class LineItem < ActiveRecord::Base
  belongs_to :purchase_order
end

class NumeroTelefone < ActiveRecord::Base
end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))

### CONTROLLERS
class AuthorsController < JSONAPI::ResourceController
end

class PeopleController < JSONAPI::ResourceController
end

class PostsController < ActionController::Base
  include JSONAPI::ActsAsResourceController
end

class CommentsController < JSONAPI::ResourceController
end

class SectionsController < JSONAPI::ResourceController
end

class TagsController < JSONAPI::ResourceController
end

class IsoCurrenciesController < JSONAPI::ResourceController
end

class ExpenseEntriesController < JSONAPI::ResourceController
end

class BreedsController < JSONAPI::ResourceController
end

class FactsController < JSONAPI::ResourceController
end

### CONTROLLERS
module Api
  module V1
    class AuthorsController < JSONAPI::ResourceController
    end

    class PeopleController < JSONAPI::ResourceController
    end

    class PostsController < ActionController::Base
      include JSONAPI::ActsAsResourceController
    end

    class TagsController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class BreedsController < JSONAPI::ResourceController
    end

    class PlanetsController < JSONAPI::ResourceController
    end

    class PlanetTypesController < JSONAPI::ResourceController
    end

    class MoonsController < JSONAPI::ResourceController
    end

    class LikesController < JSONAPI::ResourceController
    end
  end

  module V2
    class AuthorsController < JSONAPI::ResourceController
    end

    class PeopleController < JSONAPI::ResourceController
    end

    class PostsController < JSONAPI::ResourceController
    end

    class PreferencesController < JSONAPI::ResourceController
    end

    class BooksController < JSONAPI::ResourceController
    end

    class BookCommentsController < JSONAPI::ResourceController
    end
  end

  module V3
    class PostsController < JSONAPI::ResourceController
    end
  end

  module V4
    class PostsController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end

    class BooksController < JSONAPI::ResourceController
    end
  end

  module V5
    class AuthorsController < JSONAPI::ResourceController
    end

    class PostsController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end
  end

  module V6
    class CustomersController < JSONAPI::ResourceController
    end

    class PurchaseOrdersController < JSONAPI::ResourceController
    end

    class LineItemsController < JSONAPI::ResourceController
    end

    class OrderFlagsController < JSONAPI::ResourceController
    end
  end

  module V7
    class CustomersController < JSONAPI::ResourceController
    end

    class PurchaseOrdersController < JSONAPI::ResourceController
    end

    class LineItemsController < JSONAPI::ResourceController
    end

    class OrderFlagsController < JSONAPI::ResourceController
    end
  end

  module V8
    class NumerosTelefoneController < JSONAPI::ResourceController
    end
  end
end

### RESOURCES
class PersonResource < JSONAPI::Resource
  attributes :id, :name, :email
  attribute :date_joined, format: :date_with_timezone

  has_many :comments
  has_many :posts

  has_one :preferences
  has_one :hair_cut

  filter :name

  def self.verify_custom_filter(filter, values, context)
    case filter
      when :name
        values.each do |value|
          if value.length < 3
            raise JSONAPI::Exceptions::InvalidFilterValue.new(filter, value)
          end
        end
    end
    return filter, values
  end
end

class CommentResource < JSONAPI::Resource
  attributes :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags
end

class TagResource < JSONAPI::Resource
  attributes :name

  has_many :posts
  # Not including the planets association so they don't get output
  #has_many :planets
end

class SectionResource < JSONAPI::Resource
  attributes 'name'
end

class PostResource < JSONAPI::Resource
  attribute :title
  attribute :body
  attribute :subject

  has_one :author, class_name: 'Person'
  has_one :section
  has_many :tags, acts_as_set: true
  has_many :comments, acts_as_set: false

  before_save do
    msg = "Before save"
  end

  after_save do
    msg = "After save"
  end

  before_update do
    msg = "Before update"
  end

  after_update do
    msg = "After update"
  end

  before_replace_fields do
    msg = "Before replace_fields"
  end

  after_replace_fields do
    msg = "After replace_fields"
  end

  around_update :around_update_check

  def around_update_check
    # do nothing
    yield
    # do nothing
  end

  def subject
    @model.title
  end

  filters :title, :author, :tags, :comments
  filters :id, :ids

  def self.updateable_fields(context)
    super(context) - [:author, :subject]
  end

  def self.createable_fields(context)
    super(context) - [:subject]
  end

  def self.sortable_fields(context)
    super(context) - [:id]
  end

  def self.verify_custom_filter(filter, values, context = nil)
    case filter
      when :id
        verify_keys(values, context)
      when :ids #coerce :ids to :id
        verify_keys(values, context)
        return :id, values
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

  def self.verify_key(key, context = nil)
    raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key) unless is_num?(key)
    raise JSONAPI::Exceptions::RecordNotFound.new(key) unless find_by_key(key, context: context)
    return key
  end
end

class HairCutResource < JSONAPI::Resource
  attribute :style
  has_many :people
end

class IsoCurrencyResource < JSONAPI::Resource
  primary_key :code
  attributes :name, :country_name, :minor_unit

  filter :country_name

  def self.verify_key(key, context = nil)
    key && String(key)
  end
end

class ExpenseEntryResource < JSONAPI::Resource
  attributes :cost
  attribute :transaction_date, format: :date

  has_one :iso_currency, foreign_key: 'currency_code'
  has_one :employee, class_name: 'Person'
end

class EmployeeResource < JSONAPI::Resource
  attributes :name, :email
  model_name 'Person'
end

class FriendResource < JSONAPI::Resource
end

class BreedResource < JSONAPI::Resource
  attribute :id, format_misspelled: :does_not_exist
  attribute :name, format: :title

  # This is unneeded, just here for testing
  routing_options :param => :id

  def self.find(filters, options = {})
    breeds = []
    $breed_data.breeds.values.each do |breed|
      breeds.push(BreedResource.new(breed, options[:context]))
    end
    breeds
  end

  def self.find_by_key(id, options = {})
    BreedResource.new($breed_data.breeds[id.to_i], options[:context])
  end
end

class PlanetResource < JSONAPI::Resource
  attribute :name
  attribute :description

  has_many :moons
  has_one :planet_type

  has_many :tags, acts_as_set: true
end

class PropertyResource < JSONAPI::Resource
  attributes :name

  has_many :planets
end

class PlanetTypeResource < JSONAPI::Resource
  attributes :name
  has_many :planets
end

class MoonResource < JSONAPI::Resource
  attribute :name
  attribute :description

  has_one :planet
end

class PreferencesResource < JSONAPI::Resource
  attribute :advanced_mode

  has_one :author, foreign_key: :person_id, class_name: 'Person'
  has_many :friends, class_name: 'Person'

  def self.find_by_key(key, options = {})
    new(Preferences.first)
  end
end

class FactResource < JSONAPI::Resource
  attribute :spouse_name
  attribute :bio
  attribute :quality_rating
  attribute :salary
  attribute :date_time_joined
  attribute :birthday
  attribute :bedtime
  attribute :photo
  attribute :cool
end

module Api
  module V1
    class WriterResource < JSONAPI::Resource
      attributes :name, :email
      model_name 'Person'
      has_many :posts

      filter :name
    end

    class LikeResource < JSONAPI::Resource
    end

    class PostResource < JSONAPI::Resource
      # V1 no longer supports tags and now calls author 'writer'
      attribute :title
      attribute :body
      attribute :subject

      has_one :writer, foreign_key: 'author_id'
      has_one :section
      has_many :comments, acts_as_set: false

      def subject
        @model.title
      end

      filters :writer
    end

    # AuthorResource = AuthorResource.dup
    PersonResource = PersonResource.dup
    CommentResource = CommentResource.dup
    TagResource = TagResource.dup
    SectionResource = SectionResource.dup
    IsoCurrencyResource = IsoCurrencyResource.dup
    ExpenseEntryResource = ExpenseEntryResource.dup
    BreedResource = BreedResource.dup
    PlanetResource = PlanetResource.dup
    PlanetTypeResource = PlanetTypeResource.dup
    MoonResource = MoonResource.dup
    PreferencesResource = PreferencesResource.dup
    EmployeeResource = EmployeeResource.dup
    FriendResource = FriendResource.dup
    HairCutResource = HairCutResource.dup
  end
end

module Api
  module V2
    PreferencesResource = PreferencesResource.dup
    # AuthorResource = AuthorResource.dup
    PersonResource = PersonResource.dup
    PostResource = PostResource.dup

    class BookResource < JSONAPI::Resource
      attribute :title
      attribute :isbn

      has_many :book_comments
    end

    class BookCommentResource < JSONAPI::Resource
      attributes :body
      has_one :book
      has_one :author, class_name: 'Person'
    end
  end
end

module Api
  module V3
    PostResource = PostResource.dup
    PreferencesResource = PreferencesResource.dup
  end
end

module Api
  module V4
    PostResource = PostResource.dup
    ExpenseEntryResource = ExpenseEntryResource.dup
    IsoCurrencyResource = IsoCurrencyResource.dup

    class BookResource < Api::V2::BookResource
      paginator :paged
    end
  end
end

module Api
  module V5
    class AuthorResource < JSONAPI::Resource
      attributes :name, :email
      model_name 'Person'
      has_many :posts

      filter :name

      def self.find(filters, options = {})
        resources = []

        filters.each do |attr, filter|
          _model_class.where("\"#{attr}\" LIKE \"%#{filter[0]}%\"").each do |model|
            resources.push self.new(model, options[:context])
          end
        end
        return resources
      end

      def fetchable_fields
        super - [:email]
      end
    end

    PersonResource = PersonResource.dup
    PostResource = PostResource.dup
    ExpenseEntryResource = ExpenseEntryResource.dup
    IsoCurrencyResource = IsoCurrencyResource.dup
    EmployeeResource = EmployeeResource.dup
  end
end

module Api
  module V6
    class CustomerResource < JSONAPI::Resource
      attribute :name

      has_many :purchase_orders
    end

    class PurchaseOrderResource < JSONAPI::Resource
      attribute :order_date
      attribute :requested_delivery_date
      attribute :delivery_date
      attribute :delivery_name
      attribute :delivery_address_1
      attribute :delivery_address_2
      attribute :delivery_city
      attribute :delivery_state
      attribute :delivery_postal_code
      attribute :delivery_fee
      attribute :tax
      attribute :total

      has_one :customer
      has_many :line_items
      has_many :order_flags, acts_as_set: true
    end

    class OrderFlagResource < JSONAPI::Resource
      attributes :name

      has_many :purchase_orders
    end

    class LineItemResource < JSONAPI::Resource
      attribute :part_number
      attribute :quantity
      attribute :item_cost

      has_one :purchase_order
    end
  end

  module V7
    CustomerResource = V6::CustomerResource.dup
    PurchaseOrderResource = V6::PurchaseOrderResource.dup
    OrderFlagResource = V6::OrderFlagResource.dup
    LineItemResource = V6::LineItemResource.dup
  end

  module V8
    class NumeroTelefoneResource < JSONAPI::Resource
      attribute :numero_telefone
    end
  end
end

warn 'start testing Name Collisions'
# The name collisions only emmit warnings. Exceptions would change the flow of the tests

class LinksResource < JSONAPI::Resource

end

class BadlyNamedAttributesResource < JSONAPI::Resource
  attributes :type, :href, :links

  has_many :links
  has_one :href
  has_one :id
  has_many :types
end
warn 'end testing Name Collisions'

### PORO DATA
gas_giant = PlanetType.create(name: 'Gas Giant')
planetoid = PlanetType.create(name: 'Planetoid')
terrestrial = PlanetType.create(name: 'Terrestrial')
sulfuric = PlanetType.create(name: 'Sulfuric')
unknown = PlanetType.create(name: 'unknown')

saturn = Planet.create(name: 'Satern',
                       description: 'Saturn is the sixth planet from the Sun and the second largest planet in the Solar System, after Jupiter.',
                       planet_type_id: planetoid.id)
titan = Moon.create(name:'Titan', description: 'Best known of the Saturn moons.', planet_id: saturn.id)
pluto = Planet.create(name: 'Pluto', description: 'Pluto is the smallest planet.', planet_type_id: planetoid.id)
uranus = Planet.create(name: 'Uranus', description: 'Insert adolescent jokes here.', planet_type_id: gas_giant.id)
jupiter = Planet.create(name: 'Jupiter', description: 'A gas giant.', planet_type_id: gas_giant.id)
betax = Planet.create(name: 'Beta X', description: 'Newly discovered Planet X', planet_type_id: unknown.id)
betay = Planet.create(name: 'Beta X', description: 'Newly discovered Planet Y', planet_type_id: unknown.id)
betaz = Planet.create(name: 'Beta X', description: 'Newly discovered Planet Z', planet_type_id: unknown.id)
betaw = Planet.create(name: 'Beta W', description: 'Newly discovered Planet W')
