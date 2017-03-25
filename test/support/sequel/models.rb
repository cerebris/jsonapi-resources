require 'sequel'
require 'jsonapi-resources'
require_relative 'schema'

config = Rails.configuration.database_configuration["test"]
config["adapter"] = "sqlite" if config["adapter"]=="sqlite3"
Sequel.connect(config)

Sequel::Model.class_eval do
  plugin :validation_class_methods
  plugin :hook_class_methods
  plugin :timestamps, update_on_create: true
  plugin :single_table_inheritance, :type
end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'preferences'
  inflect.irregular 'numero_telefone', 'numeros_telefone'
end

### MODELS
class Person < Sequel::Model
  one_to_many :posts, key: 'author_id'
  one_to_many :comments, key: 'author_id'
  one_to_many :expense_entries, key: 'employee_id', dependent: :restrict_with_exception
  one_to_many :vehicles
  many_to_one :preferences
  many_to_one :hair_cut
  one_to_one :author_detail

  many_to_many :books, join_table: :book_authors

  one_to_many :even_posts, conditions: 'posts.id % 2 = 0', class: 'Post', key: 'author_id'
  one_to_many :odd_posts, conditions: 'posts.id % 2 = 1', class: 'Post', key: 'author_id'

  ### Validations
  validates_presence_of :name, :date_joined
end

class AuthorDetail < Sequel::Model
  many_to_one :author, class: 'Person', key: 'person_id'
end

class Post < Sequel::Model
  many_to_one :author, class: 'Person', key: 'author_id'
  many_to_one :writer, class: 'Person', key: 'author_id'
  one_to_many :comments
  many_to_many :tags, join_table: :posts_tags
  one_to_many :special_post_tags, source: :tag
  one_to_many :special_tags, through: :special_post_tags, source: :tag
  many_to_one :section
  one_to_one :parent_post, class: 'Post', key: 'parent_post_id'

  validates_presence_of :author
  validates_length_of :title, maximum: 35

  before_destroy :destroy_callback

  def destroy_callback
    if title == "can't destroy me"
      errors.add(:title, "can't destroy me")

      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        throw(:abort)
      else
        return false
      end
      # :nocov:
    end
  end
end

class SpecialPostTag < Sequel::Model
  many_to_one :tag
  many_to_one :post
end

class Comment < Sequel::Model
  many_to_one :author, class: 'Person', key: 'author_id'
  many_to_one :post
  many_to_many :tags, join_table: :comments_tags
end

class Company < Sequel::Model
end

class Firm < Company
end

class Tag < Sequel::Model
  many_to_many :posts, join_table: :posts_tags
  many_to_many :planets, join_table: :planets_tags
end

class Section < Sequel::Model
  one_to_many :posts
end

class HairCut < Sequel::Model
  one_to_many :people
end

class Property < Sequel::Model
end

class Customer < Sequel::Model
end

class BadlyNamedAttributes < Sequel::Model
end

class Cat < Sequel::Model
end

class IsoCurrency < Sequel::Model
  set_primary_key :code
  # one_to_many :expense_entries, key: 'currency_code'
end

class ExpenseEntry < Sequel::Model
  many_to_one :employee, class: 'Person', key: 'employee_id'
  many_to_one :iso_currency, key: 'currency_code'
end

class Planet < Sequel::Model
  one_to_many :moons
  many_to_one :planet_type

  many_to_many :tags, join_table: :planets_tags

  # Test model callback cancelling save
  before_save :check_not_pluto

  def check_not_pluto
    # Pluto can't be a planet, so cancel the save
    if name.downcase == 'pluto'
      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        throw(:abort)
      else
        return false
      end
      # :nocov:
    end
  end
end

class PlanetType < Sequel::Model
  one_to_many :planets
end

class Moon < Sequel::Model
  many_to_one :planet

  one_to_many :craters
end

class Crater < Sequel::Model
  set_primary_key :code

  many_to_one :moon
end

class Preferences < Sequel::Model
  one_to_one :author, class: 'Person', :inverse_of => 'preferences'
end

class Fact < Sequel::Model
  validates_presence_of :spouse_name, :bio
end

class Like < Sequel::Model
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
    @errors = Sequel::Model::Errors.new
  end

  attr_accessor :id, :name

  def destroy
    $breed_data.remove(@id)
  end

  def valid?(context = nil)
    @errors.clear
    if name.is_a?(String) && name.length > 0
      return true
    else
      @errors.add(:name, "can't be blank")
      return false
    end
  end

  def errors
    @errors
  end
end

class Book < Sequel::Model
  one_to_many :book_comments
  one_to_many :approved_book_comments, conditions: {approved: true}, class: "BookComment"

  many_to_many :authors, join_table: :book_authors, class: "Person"
end

class BookComment < Sequel::Model
  many_to_one :author, class: 'Person', key: 'author_id'
  many_to_one :book

  def before_save
    debugger
  end

  def self.for_user(current_user)
    records = self
    # Hide the unapproved comments from people who are not book admins
    unless current_user && current_user.book_admin
      records = records.where(approved: true)
    end
    records
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

class Customer < Sequel::Model
  one_to_many :purchase_orders
end

class PurchaseOrder < Sequel::Model
  many_to_one :customer
  one_to_many :line_items
  one_to_many :admin_line_items, class: 'LineItem', key: 'purchase_order_id'

  many_to_many :order_flags, join_table: :purchase_orders_order_flags

  many_to_many :admin_order_flags, join_table: :purchase_orders_order_flags, class: 'OrderFlag'
end

class OrderFlag < Sequel::Model
  many_to_many :purchase_orders, join_table: :purchase_orders_order_flags
end

class LineItem < Sequel::Model
  many_to_one :purchase_order
end

class NumeroTelefone < Sequel::Model
end

class Category < Sequel::Model
end

class Picture < Sequel::Model
  many_to_one :imageable, polymorphic: true
end

class Vehicle < Sequel::Model
  many_to_one :person
end

class Car < Vehicle
end

class Boat < Vehicle
end

class Document < Sequel::Model
  one_to_many :pictures, as: :imageable
end

class Document::Topic < Document
end

class Product < Sequel::Model
  one_to_one :picture, as: :imageable
end

class Make < Sequel::Model
end

class WebPage < Sequel::Model
end

class Box < Sequel::Model
  one_to_many :things
end

class User < Sequel::Model
  one_to_many :things
end

class Thing < Sequel::Model
  many_to_one :box
  many_to_one :user

  one_to_many :related_things, key: :from_id
  one_to_many :things, through: :related_things, source: :to
end

class RelatedThing < Sequel::Model
  many_to_one :from, class: Thing, key: :from_id
  many_to_one :to, class: Thing, key: :to_id
end

class Question < Sequel::Model
  one_to_one :answer

  def respondent
    answer.try(:respondent)
  end
end

class Answer < Sequel::Model
  many_to_one :question
  many_to_one :respondent, polymorphic: true
end

class Patient < Sequel::Model
end

class Doctor < Sequel::Model
end

module Api
  module V7
    class Client < Customer
    end

    class Customer < Customer
    end
  end
end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))
