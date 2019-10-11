class Session < ActiveRecord::Base
  self.primary_key = "id"
  has_many :responses
end

class Response < ActiveRecord::Base
  belongs_to :session
  has_one :paragraph, :class_name => "ResponseText::Paragraph"

  def response_type
    case self.type
    when "Response::SingleTextbox"
          "single_textbox"
    else
          "question"
    end
  end
  def response_type=type
    self.type = case type
    when "single_textbox"
          "Response::SingleTextbox"
    else
      "Response"
    end
  end
end

class Response::SingleTextbox < Response
  has_one :paragraph, :class_name => "ResponseText::Paragraph", :foreign_key => :response_id
end

class ResponseText < ActiveRecord::Base
end

class ResponseText::Paragraph < ResponseText
end

class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :book_comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception
  has_many :vehicles
  belongs_to :preferences
  belongs_to :hair_cut
  has_one :author_detail

  has_and_belongs_to_many :books, join_table: :book_authors
  has_and_belongs_to_many :not_banned_books, -> { merge(Book.not_banned) },
                          class_name: 'Book',
                          join_table: :book_authors

  has_many :even_posts, -> { where('posts.id % 2 = 0') }, class_name: 'Post', foreign_key: 'author_id'
  has_many :odd_posts, -> { where('posts.id % 2 = 1') }, class_name: 'Post', foreign_key: 'author_id'

  has_many :pictures, foreign_key: 'author_id'

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
  has_many :special_post_tags, source: :tag
  has_many :special_tags, through: :special_post_tags, source: :tag
  belongs_to :section
  belongs_to :parent_post, class_name: 'Post', foreign_key: 'parent_post_id'

  validates :author, presence: true
  validates :title, length: { maximum: 35 }

  before_destroy :destroy_callback

  def destroy_callback
    case title
    when "can't destroy me", "can't destroy me either"
      errors.add(:base, "can't destroy me")

      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        throw(:abort)
      else
        return false
      end
      # :nocov:
    when "locked title"
      errors.add(:title, "is locked")

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

class SpecialPostTag < ActiveRecord::Base
  belongs_to :tag
  belongs_to :post
end

class Comment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :post
  has_and_belongs_to_many :tags, join_table: :comments_tags
end

class Company < ActiveRecord::Base
end

class Firm < Company
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts, join_table: :posts_tags
  has_and_belongs_to_many :planets, join_table: :planets_tags

  has_and_belongs_to_many :comments, join_table: :comments_tags
end

class Section < ActiveRecord::Base
  has_many :posts
end

class HairCut < ActiveRecord::Base
  has_many :people
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
  has_many :expense_entries, foreign_key: 'currency_code'
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
  has_one :author, class_name: 'Person', :inverse_of => 'preferences'
end

class Fact < ActiveRecord::Base
  validates :spouse_name, :bio, presence: true
end

class Like < ActiveRecord::Base
end

class Breed
  include ActiveModel::Model

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

  validates :name, presence: true
end

class Book < ActiveRecord::Base
  has_many :book_comments
  has_many :approved_book_comments, -> { where(approved: true) }, class_name: "BookComment"

  has_and_belongs_to_many :authors, join_table: :book_authors, class_name: "Person"

  scope :not_banned, -> {
    where(banned: false)
  }
end

class BookComment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :book

  def self.for_user(current_user)
    records = self.all
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
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'

  belongs_to :imageable, polymorphic: true
  belongs_to :document, -> { where( pictures: { imageable_type: 'Document' } ).eager_load( :pictures ) }, foreign_key: 'imageable_id'
  belongs_to :product, -> { where( pictures: { imageable_type: 'Product' } ).eager_load( :pictures ) }, foreign_key: 'imageable_id'

  has_one :file_properties, as: 'fileable'
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
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  has_one :file_properties, as: 'fileable'
end

class Product < ActiveRecord::Base
  has_many :pictures, as: :imageable
  belongs_to :designer, class_name: 'Person', foreign_key: 'designer_id'
  has_one :file_properties, as: 'fileable'
end

class FileProperties < ActiveRecord::Base
  belongs_to :fileable, polymorphic: true
  belongs_to :tag
end

class Make < ActiveRecord::Base
end

class WebPage < ActiveRecord::Base
end

class Box < ActiveRecord::Base
  has_many :things
end

class User < ActiveRecord::Base
  has_many :things
end

class Thing < ActiveRecord::Base
  belongs_to :box
  belongs_to :user

  has_many :related_things, foreign_key: :from_id
  has_many :things, through: :related_things, source: :to
end

class RelatedThing < ActiveRecord::Base
  belongs_to :from, class_name: "Thing", foreign_key: :from_id
  belongs_to :to, class_name: "Thing", foreign_key: :to_id
end

class Question < ActiveRecord::Base
  has_one :answer

  def respondent
    answer.try(:respondent)
  end
end

class Answer < ActiveRecord::Base
  belongs_to :question
  belongs_to :respondent, polymorphic: true
end

class Patient < ActiveRecord::Base
end

class Doctor < ActiveRecord::Base
end

module Api
  module V7
    class Client < Customer
    end

    class Customer < Customer
    end
  end
end

class Storage < ActiveRecord::Base
  has_one :keeper, class_name: 'Keeper', as: :keepable
end

class Keeper < ActiveRecord::Base
  belongs_to :keepable, polymorphic: true
end

class AccessCard < ActiveRecord::Base
  has_many :workers
end

class Worker < ActiveRecord::Base
  belongs_to :access_card
end

class Agency < ActiveRecord::Base
end

class Indicator < ActiveRecord::Base
  belongs_to :agency
  has_many :widgets, primary_key: :import_id, foreign_key: :indicator_import_id
end

class Widget < ActiveRecord::Base
  belongs_to :indicator, primary_key: :import_id, foreign_key: :indicator_import_id
end

class Robot < ActiveRecord::Base
end

class Painter < ActiveRecord::Base
  has_many :paintings
end

class Painting < ActiveRecord::Base
  belongs_to :painter
  has_many :collectors
end

class Collector < ActiveRecord::Base
  belongs_to :painting
end

class List < ActiveRecord::Base
  has_many :items, class_name: 'ListItem', inverse_of: :list
end

class ListItem < ActiveRecord::Base
  belongs_to :list, inverse_of: :items
end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))
