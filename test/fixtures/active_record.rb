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
    t.integer    :hair_cut_id, index: true
    t.boolean    :book_admin, default: false
    t.timestamps null: false
  end

  create_table :author_details, force: true do |t|
    t.integer :person_id
    t.string  :author_stuff
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

  create_table :craters, id: false, force: true do |t|
    t.string  :code
    t.string  :description
    t.integer :moon_id
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
    t.decimal  :salary, precision: 12, scale: 2
    t.datetime :date_time_joined
    t.date     :birthday
    t.time     :bedtime
    t.binary   :photo, limit: 1.kilobyte
    t.boolean  :cool
  end

  create_table :books, force: true do |t|
    t.string :title
    t.string :isbn
    t.boolean :banned, default: false
  end

  create_table :book_comments, force: true do |t|
    t.text       :body
    t.belongs_to :book, index: true
    t.integer    :author_id
    t.boolean    :approved, default: true
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

  create_table :categories, force: true do |t|
    t.string :name
    t.string :status, limit: 10
  end

  create_table :pictures, force: true do |t|
    t.string  :name
    t.integer :imageable_id
    t.string  :imageable_type
    t.timestamps null: false
  end

  create_table :documents, force: true do |t|
    t.string  :name
    t.timestamps null: false
  end

  create_table :products, force: true do |t|
    t.string  :name
    t.timestamps null: false
  end

  create_table :vehicles, force: true do |t|
    t.string :type
    t.string :make
    t.string :vehicle_model
    t.string :length_at_water_line
    t.string :drive_layout
    t.string :serial_number
    t.integer :person_id
  end
end

### MODELS
class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception
  has_many :vehicles
  belongs_to :preferences
  belongs_to :hair_cut
  has_one :author_detail

  ### Validations
  validates :name, presence: true
  validates :date_joined, presence: true
end

class AuthorDetail < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'person_id'
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

class HairCut < ActiveRecord::Base
end

class Property < ActiveRecord::Base
end

class Customer < ActiveRecord::Base
end

class BadlyNamedAttributes < ActiveRecord::Base
end

class Cat < ActiveRecord::Base
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

  # Test model callback cancelling save
  before_save :check_not_pluto

  def check_not_pluto
    # Pluto can't be a planet, so cancel the save
    if name.downcase == 'pluto'
      return false
    end
  end
end

class PlanetType < ActiveRecord::Base
  has_many :planets
end

class Moon < ActiveRecord::Base
  belongs_to :planet

  has_many :craters
end

class Crater < ActiveRecord::Base
  self.primary_key = :code

  belongs_to :moon
end

class Preferences < ActiveRecord::Base
  has_one :author, class_name: 'Person'
  has_many :friends, class_name: 'Person'
end

class Fact < ActiveRecord::Base
  validates :spouse_name, :bio, presence: true
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
  has_many :approved_book_comments, -> { where(approved: true) }, class_name: "BookComment"
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

class Customer < ActiveRecord::Base
  has_many :purchase_orders
end

class PurchaseOrder < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
  has_many :admin_line_items, class_name: 'LineItem', foreign_key: 'purchase_order_id'

  has_and_belongs_to_many :order_flags, join_table: :purchase_orders_order_flags

  has_and_belongs_to_many :admin_order_flags, join_table: :purchase_orders_order_flags, class_name: 'OrderFlag'
end

class OrderFlag < ActiveRecord::Base
  has_and_belongs_to_many :purchase_orders, join_table: :purchase_orders_order_flags
end

class LineItem < ActiveRecord::Base
  belongs_to :purchase_order
end

class NumeroTelefone < ActiveRecord::Base
end

class Category < ActiveRecord::Base
end

class Picture < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true
end

class Vehicle < ActiveRecord::Base
  belongs_to :person
end

class Car < Vehicle
end

class Boat < Vehicle
end

class Document < ActiveRecord::Base
  has_many :pictures, as: :imageable
end

class Product < ActiveRecord::Base
  has_one :picture, as: :imageable
end

### OperationsProcessor
class CountingActiveRecordOperationsProcessor < ActiveRecordOperationsProcessor
  after_find_operation do
    @operation_meta[:total_records] = @operation.record_count
    @operation_links['spec'] = 'https://test_corp.com'
  end
end

# This processor swaps in a mock for the operation that will raise an exception
# when it receives the :apply method. This is used to test the
# exception_class_whitelist configuration.
class ErrorRaisingOperationsProcessor < ActiveRecordOperationsProcessor
  def process_operation(operation)
    mock_operation = Minitest::Mock.new
    mock_operation.expect(:apply, true) do
      raise PostsController::SubSpecialError
    end
    super(mock_operation)
  end
end

### CONTROLLERS
class AuthorsController < JSONAPI::ResourceController
end

class PeopleController < JSONAPI::ResourceController
end

class PostsController < ActionController::Base
  include JSONAPI::ActsAsResourceController
  class SpecialError < StandardError; end
  class SubSpecialError < PostsController::SpecialError; end

  # This is used to test that classes that are whitelisted are reraised by
  # the operations processor.
  rescue_from PostsController::SpecialError do
    head :forbidden
  end

  #called by test_on_server_error
  def self.set_callback_message(error)
    @callback_message = "Sent from method"
  end
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

class CategoriesController < JSONAPI::ResourceController
end

class PicturesController < JSONAPI::ResourceController
end

class DocumentsController < JSONAPI::ResourceController
end

class ProductsController < JSONAPI::ResourceController
end

class ImageablesController < JSONAPI::ResourceController
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

    class CratersController < JSONAPI::ResourceController
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
      def context
        {current_user: $test_user}
      end
    end

    class BookCommentsController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
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
      def context
        {current_user: $test_user}
      end
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
class BaseResource < JSONAPI::Resource
  abstract
end

class PersonResource < BaseResource
  attributes :id, :name, :email
  attribute :date_joined, format: :date_with_timezone

  has_many :comments
  has_many :posts
  has_many :vehicles, polymorphic: true

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

class VehicleResource < JSONAPI::Resource
  has_one :person
  attributes :make, :vehicle_model, :serial_number
end

class CarResource < VehicleResource
  attributes :drive_layout
end

class BoatResource < VehicleResource
  attributes :length_at_water_line
end

class CommentResource < JSONAPI::Resource
  attributes :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags

  filters :body
end

class TagResource < JSONAPI::Resource
  attributes :name

  has_many :posts
  # Not including the planets relationship so they don't get output
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

  # Not needed - just for testing
  primary_key :id

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

  def title=(title)
    @model.title = title
    if title == 'BOOM'
      raise 'The Server just tested going boom. If this was a real emergency you would be really dead right now.'
    end
  end

  filters :title, :author, :tags, :comments
  filters :id, :ids

  def self.updatable_fields(context)
    super(context) - [:author, :subject]
  end

  def self.creatable_fields(context)
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

  def self.verify_key(key, context = nil)
    super(key)
    raise JSONAPI::Exceptions::RecordNotFound.new(key) unless find_by_key(key, context: context)
    return key
  end
end

class HairCutResource < JSONAPI::Resource
  attribute :style
  has_many :people
end

class IsoCurrencyResource < JSONAPI::Resource
  attributes :name, :country_name, :minor_unit

  filter :country_name

  key_type :string
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
  routing_options param: :id

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

  def _save
    super
    return :accepted
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
  has_many :craters
end

class CraterResource < JSONAPI::Resource
  attribute :code
  attribute :description

  has_one :moon

  def self.verify_key(key, context = nil)
    key && String(key)
  end
end

class PreferencesResource < JSONAPI::Resource
  attribute :advanced_mode

  has_one :author, foreign_key: :person_id
  has_many :friends

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

class CategoryResource < JSONAPI::Resource
  filter :status, default: 'active'
end

class PictureResource < JSONAPI::Resource
  attribute :name
  has_one :imageable, polymorphic: true
end

class DocumentResource < JSONAPI::Resource
  attribute :name
  has_many :pictures
end

class ProductResource < JSONAPI::Resource
  attribute :name
  has_one :picture, always_include_linkage_data: true

  def picture_id
    model.picture.id
  end
end

class ImageableResource < JSONAPI::Resource
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

      has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
      has_one :section
      has_many :comments, acts_as_set: false

      def subject
        @model.title
      end

      filters :writer
    end

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
    CraterResource = CraterResource.dup
    PreferencesResource = PreferencesResource.dup
    EmployeeResource = EmployeeResource.dup
    FriendResource = FriendResource.dup
    HairCutResource = HairCutResource.dup
    VehicleResource = VehicleResource.dup
    CarResource = CarResource.dup
    BoatResource = BoatResource.dup
  end
end

module Api
  module V2
    PreferencesResource = PreferencesResource.dup
    PersonResource = PersonResource.dup
    PostResource = PostResource.dup

    class BookResource < JSONAPI::Resource
      attribute :title
      attributes :isbn, :banned

      has_many :book_comments, relation_name: -> (options = {}) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        unless current_user && current_user.book_admin
          :approved_book_comments
        else
          :book_comments
        end
      }

      has_many :aliased_comments, class_name: 'BookComments', relation_name: :approved_book_comments

      filters :banned, :book_comments

      class << self
        def apply_filter(records, filter, value, options)
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          case filter
            when :banned
              # Only book admins my filter for banned books
              if current_user && current_user.book_admin
                return records.where('books.banned = ?', value[0] == 'true')
              end
            else
              return super(records, filter, value)
          end
        end

        def books
          Book.arel_table
        end

        def not_banned_books
          books[:banned].eq(false)
        end

        def records(options = {})
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          records = _model_class
          # Hide the banned books from people who are not book admins
          unless current_user && current_user.book_admin
            records = records.where(not_banned_books)
          end
          records
        end
      end
    end

    class BookCommentResource < JSONAPI::Resource
      attributes :body, :approved

      has_one :book
      has_one :author, class_name: 'Person'

      filters :approved, :book

      class << self
        def book_comments
          BookComment.arel_table
        end

        def approved_comments(approved = true)
          book_comments[:approved].eq(approved)
        end

        def apply_filter(records, filter, value, options)
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          case filter
            when :approved
              # Only book admins my filter for unapproved comments
              if current_user && current_user.book_admin
                records.where(approved_comments(value[0] == 'true'))
              end
            else
              #:nocov:
              return super(records, filter, value)
            #:nocov:
          end
        end

        def records(options = {})
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          records = _model_class
          # Hide the unapproved comments from people who are not book admins
          unless current_user && current_user.book_admin
            records = records.where(approved_comments)
          end
          records
        end
      end
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

    class BookCommentResource < Api::V2::BookCommentResource
      paginator :paged
    end
  end
end

module Api
  module V5
    class AuthorResource < JSONAPI::Resource
      attributes :name, :email
      model_name 'Person'
      relationship :posts, to: :many
      relationship :author_detail, to: :one, foreign_key_on: :related

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

    class AuthorDetailResource < JSONAPI::Resource
      attributes :author_stuff
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
      has_many :line_items, relation_name: -> (options = {}) {
                            context = options[:context]
                            current_user = context ? context[:current_user] : nil

                            unless current_user && current_user.book_admin
                              :line_items
                            else
                              :admin_line_items
                            end
                          }

      has_many :order_flags, acts_as_set: true,
               relation_name: -> (options = {}) {
                             context = options[:context]
                             current_user = context ? context[:current_user] : nil

                             unless current_user && current_user.book_admin
                               :order_flags
                             else
                               :admin_order_flags
                             end
                           }
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

module AdminApi
  module V1
    class PersonResource < JSONAPI::Resource
    end
  end
end

module MyEngine
  module Api
    module V1
      class PersonResource < JSONAPI::Resource
      end
    end
  end

  module AdminApi
    module V1
      class PersonResource < JSONAPI::Resource
      end
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

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))
