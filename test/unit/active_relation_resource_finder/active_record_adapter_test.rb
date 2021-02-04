require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class ActiveRecordAdapterTest < ActiveSupport::TestCase

  def test_joins_left
    sql = Post.joins_left(:comments).to_sql
    assert_equal 'SELECT "posts".* FROM "posts" LEFT OUTER JOIN "comments" ON "comments"."post_id" = "posts"."id"',
                 sql
  end

  def test_joins_left_through_inner
    sql = Post.joins(:comments).joins_left(comments: :author).to_sql
    assert_equal 'SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id" ' \
                 'LEFT OUTER JOIN "people" ON "people"."id" = "comments"."author_id"',
                 sql
  end
end
