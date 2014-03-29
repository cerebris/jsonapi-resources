require 'active_record'
require 'json/api/serializer'

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => ':memory:'
)

ActiveRecord::Schema.define do
  create_table :ar_people, force: true do |t|
    t.string     :name
    t.string     :email
    t.datetime   :date_joined
    t.timestamps
  end

  create_table :ar_posts, force: true do |t|
    t.string     :title
    t.text       :body
    #t.integer    :author_id
    t.belongs_to :ar_section, index: true
    t.timestamps
  end

  create_table :ar_comments, force: true do |t|
    t.text       :body
    t.belongs_to :ar_post, index: true
    #t.integer    :author_id
    t.timestamps
  end

  create_table :ar_tags, force: true do |t|
    t.string :name
  end

  create_table :ar_sections, force: true do |t|
    t.string :name
  end

  create_table :ar_posts_tags, force: true do |t|
    t.references :ar_post, :ar_tag, index: true
  end

  create_table :ar_comments_tags, force: true do |t|
    t.references :ar_comment, :ar_tag, index: true
  end
end

#class ARPerson < ActiveRecord::Base
#  has_many :ar_posts, class_name: 'ARPost'
#  has_many :ar_comments, class_name: 'ARComment'
#end

class ARPost < ActiveRecord::Base
  #belongs_to :author, class_name: 'ARPerson', foreign_key: 'author_id'
  has_many :ar_comments, class_name: 'ARComment'
  has_and_belongs_to_many :ar_tags, class_name: 'ARTag', join_table: :ar_posts_tags
  belongs_to :ar_section, class_name: 'ARSection'
end

class ARComment < ActiveRecord::Base
  #belongs_to :author, class_name: 'ARPerson', foreign_key: 'author_id'
  belongs_to :ar_post, class_name: 'ARPost'
  has_and_belongs_to_many :ar_tags, class_name: 'ARTag', join_table: :ar_comments_tags
end

class ARTag < ActiveRecord::Base
end

class ARSection < ActiveRecord::Base
end

#class ARPersonSerializer < ActiveModel::Serializer
#  attributes :name, :email, :date_joined
#end

class ARPostSerializer < JSON::API::Serializer
  #attributes :id, :title, :body
  #
  #has_many :ar_comments, :ar_tags
  #has_one  :ar_section
  #has_one :author, class_name: 'ARPeople'
end

class ARCommentSerializer < JSON::API::Serializer
  #attributes :id, :body
  #has_one :ar_post
  #has_many :ar_tags
end

class ARTagSerializer < JSON::API::Serializer
  #attributes :id, :name
end

class ARSectionSerializer < JSON::API::Serializer
  #attributes 'name'
end

#a = ARPerson.create(name: 'Joe Author',
#                    email: 'joe@xyz.fake',
#                    date_joined: DateTime.parse('2013-08-07 20:25:00 UTC +00:00'))

ARPost.create(title: 'New post',
              body:  'A body!!!',
              #author_id: a.id,
              ar_section: ARSection.create(name: 'ruby')).tap do |post|

  short_tag = post.ar_tags.create(name: 'short')
  whiny_tag = post.ar_tags.create(name: 'whiny')
  happy_tag = ARTag.create(name: 'happy')

  post.ar_comments.create(body: 'what a dumb post').tap do |comment|
    comment.ar_tags.concat happy_tag, whiny_tag
  end

  post.ar_comments.create(body: 'i liked it').tap do |comment|
    comment.ar_tags.concat happy_tag, short_tag
  end
end
