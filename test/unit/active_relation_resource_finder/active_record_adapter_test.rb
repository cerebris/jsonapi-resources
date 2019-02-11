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

    # Note this joins_left reverts to left_joins on rails 5.2 and later
    # This behaves slightly differently in that the base join table is joined twice using left the second time (in this test).
    # This should produce the same result set, but will be slightly less efficient on the database
    if Rails::VERSION::MAJOR >= 5 && ActiveRecord::VERSION::MINOR >= 2
      assert_equal 'SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id" '\
                   'LEFT OUTER JOIN "comments" "comments_posts" ON "comments_posts"."post_id" = "posts"."id" '\
                   'LEFT OUTER JOIN "people" ON "people"."id" = "comments_posts"."author_id"',
                   sql
    else
      assert_equal 'SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id" ' \
                   'LEFT OUTER JOIN "people" ON "people"."id" = "comments"."author_id"',
                   sql
    end
  end
end
