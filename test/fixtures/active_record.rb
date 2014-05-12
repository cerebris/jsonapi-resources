require 'active_record'
require 'json/api/resource_controller'
require 'json/api/resource'
require 'rails'
require 'rails/all'

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => ':memory:'
)

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
end

### MODELS
class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
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
end

class Section < ActiveRecord::Base
end

### CONTROLLERS
class PostsController < JSON::API::ResourceController
end

### RESOURCES
class PersonResource < JSON::API::Resource
  attributes :id, :name, :email, :date_joined
  has_many :comments
  has_many :posts, foreign_key: 'author_id'
end

 class CommentResource < JSON::API::Resource
  attributes :id, :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags
 end

 class TagResource < JSON::API::Resource
  attributes :id, :name
 end

class SectionResource < JSON::API::Resource
  attributes 'name'
  type :category
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

  filters [:title, :author]
  filter :id
end

### DATA
a = Person.create(name: 'Joe Author',
                 email: 'joe@xyz.fake',
                 date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'))

b = Person.create(name: 'Fred Reader',
                 email: 'fred@xyz.fake',
                 date_joined: DateTime.parse('2013-10-31 20:25:00 UTC +00:00'))

Post.create(title: 'New post',
              body:  'A body!!!',
              author_id: a.id,
              section: Section.create(name: 'ruby')).tap do |post|

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


