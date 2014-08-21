## Overview

Resources
* implies a route, controllers, model, serializer
* any level could be overridden

Models

Controllers
* linked to a resource

Serializers
* linked to a resource

Routes

## Resources

Specify the following:
* relationships
* attributes
  * sortable
  * default_sort

```
class ApplicationResource < JSONAPI::Resource
end

class PostResource < ApplicationResource
  hasMany :comments
  hasOne :author, type: :person
  hasOne :editor, type: :person
  attribute :title
  attribute :content, sortable: false
  attribute :created_at, sortable: :date, default_sort: true

  def fetchable(keys)
    if scope.admin?
      keys
    else
      keys - [:editor]
    end
  end

  def updateable(keys)
    fetchable(keys) - [:created_at, :updated_at]
  end

  def creatable(keys)
    updateable(keys)
  end
end

class CommentResource < ApplicationResource
  hasOne :post
  hasOne :author
  hasOne :parentComment
  attribute :content
end
```

## Serializers

class ApplicationSerializer < JSONAPI::Serializer

end

class PostSerializer < ApplicationSerializer
  hasMany :comments
  hasOne :author
  attribute :title
  attribute :content
  attribute :created_at

  #  resource :post
end

class CommentSerializer < ApplicationSerializer
end


## Controllers

ApplicationController < JSONAPI::Controller

PostController < ApplicationController

CommentController < ApplicationController