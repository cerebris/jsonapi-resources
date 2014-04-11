require 'active_record'
require 'json/api/serializer'
require 'json/api/controller'
require 'json/api/resource'
require 'rails'
require 'rails/all'

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => ':memory:'
)

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
    #t.integer    :author_id
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
end

class Person < ActiveRecord::Base
  has_many :posts, class_name: 'Post'
  has_many :comments, class_name: 'Comment'
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  has_many :comments, class_name: 'Comment'
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: :posts_tags
  belongs_to :section, class_name: 'Section'
end

class Comment < ActiveRecord::Base
  #belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :post, class_name: 'Post'
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: :comments_tags
end

class Tag < ActiveRecord::Base
end

class Section < ActiveRecord::Base
end

class PersonResource < JSON::API::Resource
  attributes :id, :name, :email, :date_joined
end

 class CommentResource < JSON::API::Resource
  attributes :id, :body
  has_one :post
  has_many :tags
 end

 class TagResource < JSON::API::Resource
  attributes :id, :name
 end

class SectionResource < JSON::API::Resource
  attributes 'name'
end

class PostsController < JSON::API::Controller
  def index
    render json: resource.model_class.all
  end

  def show
  end
end

class PostResource < JSON::API::Resource
  attribute :id
  attribute :title
  attribute :body
  attribute :subject

  has_one :author, class_name: 'Person'
  has_many :tags
  has_many :comments
  def subject
    @object.title
  end
end

a = Person.create(name: 'Joe Author',
                 email: 'joe@xyz.fake',
                 date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'))

Post.create(title: 'New post',
              body:  'A body!!!',
              author_id: a.id,
              section: Section.create(name: 'ruby')).tap do |post|

  short_tag = post.tags.create(name: 'short')
  whiny_tag = post.tags.create(name: 'whiny')
  happy_tag = Tag.create(name: 'happy')

  post.comments.create(body: 'what a dumb post').tap do |comment|
    comment.tags.concat whiny_tag, short_tag
  end

  post.comments.create(body: 'i liked it').tap do |comment|
    comment.tags.concat happy_tag, short_tag
  end
end


