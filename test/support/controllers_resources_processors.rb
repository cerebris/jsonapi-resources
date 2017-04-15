# Controllers, Resources, and Processors for specs.

### CONTROLLERS
class AuthorsController < JSONAPI::ResourceControllerMetal
end

class PeopleController < JSONAPI::ResourceController
end

class BaseController < ActionController::Base
  include JSONAPI::ActsAsResourceController
end

class PostsController < BaseController

  class SpecialError < StandardError; end
  class SubSpecialError < PostsController::SpecialError; end
  class SerializeError < StandardError; end

  # This is used to test that classes that are whitelisted are reraised by
  # the operations dispatcher.
  rescue_from PostsController::SpecialError do
    head :forbidden
  end

  #called by test_on_server_error
  def self.set_callback_message(error)
    @callback_message = "Sent from method"
  end

  def resource_serializer_klass
    PostSerializer
  end
end

class PostSerializer < JSONAPI::ResourceSerializer
  def initialize(*)
    if $PostSerializerRaisesErrors
      raise PostsController::SerializeError
    else
      super
    end
  end
end

class CommentsController < JSONAPI::ResourceController
end

class FirmsController < JSONAPI::ResourceController
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

class VehiclesController < JSONAPI::ResourceController
end

class CarsController < JSONAPI::ResourceController
end

class BoatsController < JSONAPI::ResourceController
end

class BooksController < JSONAPI::ResourceController
  def context
    { title: 'Title' }
  end
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
      def context
        {current_user: $test_user}
      end
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
      def serialization_options
        {foo: 'bar'}
      end
    end

    class PostsController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end
  end

  module V6
    class PostsController < JSONAPI::ResourceController
    end

    class SectionsController < JSONAPI::ResourceController
    end

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

    class CategoriesController < JSONAPI::ResourceController
    end

    class ClientsController < JSONAPI::ResourceController
    end
  end

  module V8
    class NumerosTelefoneController < JSONAPI::ResourceController
    end
  end
end

module Api
  class BoxesController < JSONAPI::ResourceController
  end
end

class QuestionsController < JSONAPI::ResourceController
end

class AnswersController < JSONAPI::ResourceController
end

class PatientsController < JSONAPI::ResourceController
end

class DoctorsController < JSONAPI::ResourceController
end

class RespondentController < JSONAPI::ResourceController
end

### RESOURCES
class BaseResource < JSONAPI::Resource
  abstract
end

class PersonResource < BaseResource
  attributes :name, :email
  attribute :date_joined, format: :date_with_timezone

  has_many :comments, :posts
  has_many :vehicles, polymorphic: true

  has_one :preferences
  has_one :hair_cut

  filter :name, verify: :verify_name_filter

  def self.verify_name_filter(values, _context)
    values.each do |value|
      if value.length < 3
        raise JSONAPI::Exceptions::InvalidFilterValue.new(:name, value)
      end
    end
    return values
  end

end

class PersonWithEvenAndOddPostsResource < JSONAPI::Resource
  model_name 'Person'

  has_many :even_posts, foreign_key: 'author_id', class_name: 'Post', relation_name: :even_posts
  has_many :odd_posts, foreign_key: 'author_id', class_name: 'Post', relation_name: :odd_posts
end

class SpecialBaseResource < BaseResource
  abstract

  model_hint model: Person, resource: :special_person
end

class SpecialPersonResource < SpecialBaseResource
  model_name 'Person'

  def self.records(options = {})
    Person.where(special: true)
  end
end

class VehicleResource < JSONAPI::Resource
  immutable

  has_one :person
  attributes :make, :model, :serial_number
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

class CompanyResource < JSONAPI::Resource
  attributes :name, :address
end

class FirmResource < CompanyResource
  model_name "Firm"
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

module ParentApi
  class PostResource < JSONAPI::Resource
    model_name 'Post'
    attributes :title
    has_one :parent_post
  end
end

class PostResource < JSONAPI::Resource
  attribute :title
  attribute :body
  attribute :subject

  has_one :author, class_name: 'Person'
  has_one :section
  has_many :tags, acts_as_set: true, inverse_relationship: :posts, eager_load_on_include: false
  has_many :comments, acts_as_set: false, inverse_relationship: :post

  # Not needed - just for testing
  primary_key :id

  def self.default_sort
    [{field: 'title', direction: :desc}, {field: 'id', direction: :desc}]
  end

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
  filter :id, verify: ->(values, context) {
    verify_keys(values, context)
    return values
  }
  filter :ids,
         verify: ->(values, context) {
           verify_keys(values, context)
           return values
         },
         apply: -> (records, value, _options) {
           records.where('id IN (?)', value)
         }

  filter :search,
    verify: ->(values, context) {
      values.all?{|v| (v.is_a?(Hash) || v.is_a?(ActionController::Parameters)) } && values
    },
    apply: -> (records, values, _options) {
      records.where(title: values.first['title'])
    }

  def self.updatable_fields(context)
    super(context) - [:author, :subject]
  end

  def self.creatable_fields(context)
    super(context) - [:subject]
  end

  def self.sortable_fields(context)
    super(context) - [:id] + [:"author.name"]
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
  attribute :id, format: :id, readonly: false

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

class BreedResource < JSONAPI::Resource
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
  has_many :planets, inverse_relationship: :planet_type
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

  filter :description, apply: -> (records, value, options) {
    fail "context not set" unless options[:context][:current_user] != nil && options[:context][:current_user] == $test_user
    records.where(:description => value)
  }

  def self.verify_key(key, context = nil)
    key && String(key)
  end
end

class PreferencesResource < JSONAPI::Resource
  attribute :advanced_mode

  has_one :author, :foreign_key_on => :related

  def self.find_records(filters, options = {})
    Preferences.limit(1)
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

class TopicResource < JSONAPI::Resource
  model_name 'Document::Topic'
  has_many :pictures
end

class ProductResource < JSONAPI::Resource
  attribute :name
  has_one :picture, always_include_linkage_data: true

  def picture_id
    _model.picture.id
  end
end

class ImageableResource < JSONAPI::Resource
end

class MakeResource < JSONAPI::Resource
  attribute :model
end

class WebPageResource < JSONAPI::Resource
  attribute :href
  attribute :link
end

class AuthorResource < JSONAPI::Resource
  model_name 'Person'
  attributes :name

  has_many :books, inverse_relationship: :authors
end

class BookResource < JSONAPI::Resource
  attribute :title

  has_many :authors, class_name: 'Author', inverse_relationship: :books

  def title
    context[:title]
  end
end

class AuthorDetailResource < JSONAPI::Resource
  attributes :author_stuff
end

class SimpleCustomLinkResource < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    { raw: options[:serializer].link_builder.self_link(self) + "/raw" }
  end
end

class CustomLinkWithRelativePathOptionResource < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    { raw: options[:serializer].link_builder.self_link(self) + "/super/duper/path.xml" }
  end
end

class CustomLinkWithIfCondition < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    if title == "JR Solves your serialization woes!"
      {conditional_custom_link: options[:serializer].link_builder.self_link(self) + "/conditional/link.json"}
    end
  end
end

class CustomLinkWithLambda < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject, :created_at

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    {
      link_to_external_api: "http://external-api.com/posts/#{ created_at.year }/#{ created_at.month }/#{ created_at.day }-#{ subject.gsub(' ', '-') }"
    }
  end
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

      def self.default_sort
        [{field: 'title', direction: :asc}, {field: 'id', direction: :desc}]
      end

      def subject
        @model.title
      end

      filters :writer
    end

    class PersonResource < PersonResource; end
    class CommentResource < CommentResource; end
    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class IsoCurrencyResource < IsoCurrencyResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class BreedResource < BreedResource; end
    class PlanetResource < PlanetResource; end
    class PlanetTypeResource < PlanetTypeResource; end
    class MoonResource < MoonResource; end
    class CraterResource < CraterResource; end
    class PreferencesResource < PreferencesResource; end
    class EmployeeResource < EmployeeResource; end
    class HairCutResource < HairCutResource; end
    class VehicleResource < VehicleResource; end
    class CarResource < CarResource; end
    class BoatResource < BoatResource; end
  end
end

module Api
  module V2
    class PreferencesResource < PreferencesResource; end
    class PersonResource < PersonResource; end
    class PostResource < PostResource; end

    class BookResource < JSONAPI::Resource
      attribute :title
      attributes :isbn, :banned

      has_many :authors

      has_many :book_comments, relation_name: -> (options = {}) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        unless current_user && current_user.book_admin
          :approved_book_comments
        else
          :book_comments
        end
      }, reflect: true

      has_many :aliased_comments, class_name: 'BookComments', relation_name: :approved_book_comments

      filters :book_comments
      filter :banned, apply: :apply_filter_banned

      class << self
        def not_banned_books
          {banned: false}
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

        def apply_filter_banned(records, value, options)
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          # Only book admins might filter for banned books
          if current_user && current_user.book_admin
            records.where('books.banned = ?', value[0] == 'true')
          end
        end

      end
    end

    class BookCommentResource < JSONAPI::Resource
      attributes :body, :approved

      has_one :book
      has_one :author, class_name: 'Person'

      filters :book
      filter :approved, apply: ->(records, value, options) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        if current_user && current_user.book_admin
          records.where(approved_comments(value[0] == 'true'))
        end
      }

      class << self
        # def book_comments
        #   BookComment.arel_table
        # end

        def approved_comments(approved = true)
          {approved: approved}
        end

        def records(options = {})
          current_user = options[:context][:current_user]
          _model_class.for_user(current_user)
        end
      end
    end
  end
end

module Api
  module V3
    class PostResource < PostResource; end
    class PreferencesResource < PreferencesResource; end
  end
end

module Api
  module V4
    class PostResource < PostResource; end
    class PersonResource < PersonResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class IsoCurrencyResource < IsoCurrencyResource; end

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

      def self.find_records(filters, options = {})
        rel = _model_class
        filters.each do |attr, filter|
          if attr.to_s == "id"
            rel = rel.where(id: filter)
          else
            rel = rel.where("\"#{attr}\" LIKE \"%#{filter[0]}%\"")
          end
        end
        rel
      end

      def fetchable_fields
        super - [:email]
      end
    end

    class AuthorDetailResource < JSONAPI::Resource
      attributes :author_stuff
    end

    class PersonResource < PersonResource; end
    class PostResource < PostResource; end
    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class CommentResource < CommentResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class IsoCurrencyResource < IsoCurrencyResource; end
    class EmployeeResource < EmployeeResource; end
  end
end

module Api
  module V6
    class PersonResource < PersonResource; end
    class TagResource < TagResource; end

    class SectionResource < SectionResource
      has_many :posts
    end

    class CommentResource < CommentResource; end

    class PostResource < PostResource
      # Test caching with SQL fragments
      # ---
      # This is the only resource in the test cases that has an ORM specific implementation
      # Rather then extracting this out, let's just keep the logic here until we have more ORM-specific
      # resources and then we can move this PostResource to a "resources.rb" for each ORM type.
      # That seems like overkill and too much indirection for now, so keeping all resources in one spot.
      def self.records(options = {})
        if _model_class.respond_to?(:with_sql)
          _model_class.association_join(:author).select_all(:posts)
        else
          _model_class.all.joins('INNER JOIN people on people.id = author_id')
        end
      end
    end

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
                          },
               reflect: false

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

      has_many :purchase_orders, reflect: false
    end

    class LineItemResource < JSONAPI::Resource
      attribute :part_number
      attribute :quantity
      attribute :item_cost

      has_one :purchase_order
    end
  end

  module V7
    class PurchaseOrderResource < V6::PurchaseOrderResource; end
    class OrderFlagResource < V6::OrderFlagResource; end
    class LineItemResource < V6::LineItemResource; end

    class CustomerResource < V6::CustomerResource
      model_name 'Api::V7::Customer'
    end

    class ClientResource < JSONAPI::Resource
      model_name 'Api::V7::Customer'

      attribute :name

      has_many :purchase_orders
    end

    class CategoryResource < CategoryResource
      attribute :name

      # Raise exception for failure in controller
      def name
        fail "Something Exceptional Happened"
      end
    end
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

module DasherizedNamespace
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

  module DasherizedNamespace
    module V1
      class PersonResource < JSONAPI::Resource
      end
    end
  end
end

module ApiV2Engine
  class PersonResource < JSONAPI::Resource
  end
end

class FlatPostResource < JSONAPI::Resource
  model_name "Legacy::FlatPost", add_model_hint: false

  model_hint model: "Legacy::FlatPost", resource: FlatPostResource

  attribute :title
end

class FlatPostsController < JSONAPI::ResourceController
end

# CustomProcessors
class Api::V4::BookProcessor < JSONAPI::Processor
  after_find do
    unless @results.is_a?(JSONAPI::ErrorsOperationResult)
      @result.meta[:total_records] = @result.record_count
      @result.links['spec'] = 'https://test_corp.com'
    end
  end
end

class PostProcessor < JSONAPI::Processor
  def find
    if $PostProcessorRaisesErrors
      raise PostsController::SubSpecialError
    end
    # puts("In custom Operations Processor without Namespace")
    super
  end

  after_find do
    unless @results.is_a?(JSONAPI::ErrorsOperationResult)
      @result.meta[:total_records] = @result.record_count
      @result.links['spec'] = 'https://test_corp.com'
    end
  end
end

module Api
  module V7
    class CategoryProcessor < JSONAPI::Processor
      def show
        if $PostProcessorRaisesErrors
          raise PostsController::SubSpecialError
        end
        # puts("In custom Operations Processor without Namespace")
        super
      end
    end
  end
end

module Api
  module V1
    class PostProcessor < JSONAPI::Processor
      def show
        # puts("In custom Operations Processor with Namespace")
        super
      end
    end
  end
end

module Api
  class BoxResource < JSONAPI::Resource
    has_many :things
  end

  class ThingResource < JSONAPI::Resource
    has_one :box
    has_one :user

    has_many :things
  end

  class UserResource < JSONAPI::Resource
    has_many :things
  end
end

class QuestionResource < JSONAPI::Resource
  has_one :answer
  has_one :respondent, polymorphic: true, class_name: "Respondent", foreign_key_on: :related

  attributes :text
end

class AnswerResource < JSONAPI::Resource
  has_one :question
  has_one :respondent, polymorphic: true
end

class PatientResource < JSONAPI::Resource
  attributes :name
end

class DoctorResource < JSONAPI::Resource
  attributes :name
end

class RespondentResource < JSONAPI::Resource
  abstract
end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))
