# JSONAPI::Resources

JSONAPI::Resources, or "JR", provides a framework for developing a server that complies with the [JSON API](http://jsonapi.org/) specification.

Like JSON API itself, JR's design is focused on the resources served by an API. JR needs little more than a definition of your resources, including their attributes and relationships, to make your server compliant with JSON API.

While designed primarily to use Rails, it is possible to use JR with data not backed by ActiveRecord.

## Demo App

We have a simple demo app, called [Peeps](https://github.com/cerebris/peeps), available to show how JR is used. 

## Installation

Add JR to your application's `Gemfile`:

    gem 'jsonapi-resources'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jsonapi-resources

## Usage

### Resources

Resources define the public interface to your API. A resource defines which attributes are exposed, as well as relationships to other resources.

Resource definitions should by convention be placed in a directory under app named resources, `app/resources`. The class name should be the single underscored name of the model that backs the resource with `_resource.rb` appended. For example, a `Contact` model's resource should have a class named `ContactResource` defined in a file named `contact_resource.rb`.

#### JSONAPI::Resource

Resources must be derived from `JSONAPI::Resource`, or a class that is itself derived from `JSONAPI::Resource`.

For example:

```
require 'jsonapi/resource'

class ContactResource < JSONAPI::Resource
end
```

#### Attributes

Any of a resource's attributes that are accessible must be explicitly declared. Single attributes can be declared using the `attribute` method, and multiple attributes can be declared with the `attributes` method on the resource class.

For example:

```
require 'jsonapi/resource'

class ContactResource < JSONAPI::Resource
  attribute :id
  attribute :name_first
  attributes :name_last, :email, :twitter
end
```

This resource has 5 attributes: `:id`, `:name_first`, `:name_last`, `:email`, `:twitter`. By default these attributes must exist on the model that is handled by the resource.

A resource object wraps a Ruby object, usually an ActiveModel record, which is available as the `@object` variable. This allows a resource's methods to access the underlying object. 

For example, a computed attribute for `full_name` could be defined as such:

```
require 'jsonapi/resource'

class ContactResource < JSONAPI::Resource
  attributes :id, :name_first, :name_last, :email, :twitter
  attribute :full_name

  def full_name
    "#{@object.name_first}, #{@object.name_last}"
  end
end
```

##### Fetchable Attributes

By default all attributes are assumed to be fetchable. The list of fetchable attributes can be filtered by overriding the `fetchable` method. 

Here's a contrived example that prevents the email from being returned for resources with an odd `id`:

```
class AuthorResource < JSONAPI::Resource
  attributes :id, :name, :email
  model_name 'Person'
  has_many :posts

  def fetchable(keys, context = nil)
    if (@object.id % 2) == 1
      super(keys - [:email])
    else
      super(keys)
    end
  end

end
```

Context flows through from the controller and can be used to control the attributes based on the current user (or other value)).

##### Creatable and Updateable Attributes

By default all attributes are assumed to be updateble and creatable. To prevent some attributes from being accepted by the `update` or `create` methods, override the `self.updateable` and `self.creatable` methods on a resource.

This example prevents `full_name` from being set:

```
require 'jsonapi/resource'

class ContactResource < JSONAPI::Resource
  attributes :id, :name_first, :name_last, :email, :twitter
  attribute :full_name

  def full_name
    "#{@object.name_first}, #{@object.name_last}"
  end

  def self.updateable(keys, context = nil)
    super(keys - [:full_name])
  end

  def self.createable(keys, context = nil)
    super(keys - [:full_name])
  end
end
```

The `context` is not used by the `ResourceController`, but may be used if you override the controller methods.

#### Key

The primary key of the resource defaults to `id`, which can be changed using the `key` method.

```
class CurrencyResource < JSONAPI::Resource
  key :code
  attributes :code, :name

  has_many :expense_entries
end

```

#### Model Name

The name of the underlying model is inferred from the Resource name. It can be overridden by use of the `model_name` method. For example:

```
class AuthorResource < JSONAPI::Resource
  attributes :id, :name
  model_name 'Person'
  has_many :posts
end
```

#### Associations

Related resources need to be specified in the resource. These are declared with the `has_one` and the `has_many` methods. 

Here's a simple example where a post has a single author and an author can have many posts:

```
class PostResource < JSONAPI::Resource
  attribute :id, :title, :body

  has_one :author
end
```

And the corresponding author:

```
class AuthorResource < JSONAPI::Resource
  attribute :id, :name

  has_many :posts
end
```

##### Options

The association methods support the following options:
 * `class_name` - a string specifying the underlying class for the related resource
 * `primary_key` - the primary key to the related resource, if different than `id`
 * `key` - the key in the resource that identifies the related resource, if different than `<resource_name>_id`
 * `treat_as_set` - allows the entire set of related records to be replaced in one operation. Defaults to false if not set.

Examples:

```
 class CommentResource < JSONAPI::Resource
  attributes :id, :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags, treat_as_set: true
 end
```

```
class ExpenseEntryResource < JSONAPI::Resource
  attributes :id, :cost, :transaction_date

  has_one :currency, class_name: 'Currency', key: 'currency_code'
  has_one :employee
end
```

#### Filters

Filters for locating objects of the resource type are specified in the resource definition. Single filters can be declared using the `filter` method, and multiple filters can be declared with the `filters` method on the
resource class. 

For example:

```
require 'jsonapi/resource'

class ContactResource < JSONAPI::Resource
  attributes :id, :name_first, :name_last, :email, :twitter

  filter :id
  filters :name_first, :name_last
end
```

##### Finders

Basic finding by filters is supported by resources. However if you have more complex requirements for finding you can override the `find` and `find_by_key` methods on the resource.

Here's a hackish example:

```
class AuthorResource < JSONAPI::Resource
  attributes :id, :name
  model_name 'Person'
  has_many :posts

  filter :name

  def self.find(attrs, context = nil)
    resources = []

    attrs[:filters].each do |attr, filter|
      _model_class.where("\"#{attr}\" LIKE \"%#{filter[0]}%\"").each do |object|
        resources.push self.new(object)
      end
    end
    return resources
  end
end
```

### Controllers

JSONAPI::Resources provides a class, `ResourceController`, that can be used as the base class for your controllers. `ResourceController` supports `index`, `show`, `create`, `update`, and `destroy` methods. Just deriving your controller from `ResourceController` will give you a fully functional controller. 

For example:

```
class PeopleController < JSONAPI::ResourceController

end
```

Of course you are free to extend this as needed.

#### Error codes

Error codes are provided for each error object returned, based on the error. These errors are:

```
module JSONAPI
  VALIDATION_ERROR = 100
  INVALID_RESOURCE = 101
  FILTER_NOT_ALLOWED = 102
  INVALID_FIELD_VALUE = 103
  INVALID_FIELD = 104
  PARAM_NOT_ALLOWED = 105
  PARAM_MISSING = 106
  INVALID_FILTER_VALUE = 107
  COUNT_MISMATCH = 108
  KEY_ORDER_MISMATCH = 109
  KEY_NOT_INCLUDED_IN_URL = 110

  RECORD_NOT_FOUND = 404
  LOCKED = 423
end
```

These codes can be customized in your app by creating an initializer to override any or all of the codes.

### Serializer

The `ResourceSerializer` can be used to serialize a resource into JSON API compliant JSON. `ResourceSerializer` has a `serialize` method that takes a resource instance to serialize. For example:

```
post = Post.find(1)
JSONAPI::ResourceSerializer.new.serialize(PostResource.new(post))
```

This returns results like this:

```
{
  posts: [{
    id: 1,
    title: 'New post',
    body: 'A body!!!',
    links: {
      section: nil,
      author: 1,
      tags: [1,2,3],
      comments: [1,2]
    }
  }]
}
```                 

#### Serialize method options

The serialize method also takes some optional parameters:

##### `include`

An array of resources. Nested resources can be specified with dot notation.

  *Purpose*: determines which objects will be side loaded with the source objects in a linked section

  *Example*: ```include: ['comments','author','comments.tags','author.posts']```
  
##### `fields`

A hash of resource types and arrays of fields for each resource type.

  *Purpose*: determines which fields are serialized for a resource type. This encompasses both attributes and association ids in the links section for a resource. Fields are global for a resource type.

  *Example*: ```fields: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}```

```
post = Post.find(1)
JSONAPI::ResourceSerializer.new.serialize(PostResource.new(post),
        include: ['comments','author','comments.tags','author.posts'],
        fields: {
                 people: [:id, :email, :comments],
                 posts: [:id, :title, :author],
                 tags: [:name],
                 comments: [:id, :body, :post]})
```

##### Other fields

Arbitrary fields can also be provided to the serialize method. These will be passed to your resource when fetchable is
called. This can be used to filter the fields based on scope or other criteria.

##### `context`

You can provide context data. This is not used by the serializer, but is passed through to other methods in the resource.

#### Routing

JR has a couple of helper methods available to assist you with setting up routes.
 
##### `jsonapi_resources`

Like `resources` in ActionDispatch provides a resourceful route provides a mapping between HTTP verbs and URLs and 
controller actions. This will also setup mappings for relationship URLs for a resource's associations. For example

```
require 'jsonapi/routing_ext'

Peeps::Application.routes.draw do
  jsonapi_resources :contacts
  jsonapi_resources :phone_numbers
end
```

gives the following routes
 
```
                     Prefix Verb   URI Pattern                                               Controller#Action
contact_links_phone_numbers GET    /contacts/:contact_id/links/phone_numbers(.:format)       contacts#show_association {:association=>"phone_numbers"}
                            POST   /contacts/:contact_id/links/phone_numbers(.:format)       contacts#create_association {:association=>"phone_numbers"}
                            DELETE /contacts/:contact_id/links/phone_numbers/:keys(.:format) contacts#destroy_association {:association=>"phone_numbers"}
                   contacts GET    /contacts(.:format)                                       contacts#index
                            POST   /contacts(.:format)                                       contacts#create
                new_contact GET    /contacts/new(.:format)                                   contacts#new
               edit_contact GET    /contacts/:id/edit(.:format)                              contacts#edit
                    contact GET    /contacts/:id(.:format)                                   contacts#show
                            PATCH  /contacts/:id(.:format)                                   contacts#update
                            PUT    /contacts/:id(.:format)                                   contacts#update
                            DELETE /contacts/:id(.:format)                                   contacts#destroy
 phone_number_links_contact GET    /phone_numbers/:phone_number_id/links/contact(.:format)   phone_numbers#show_association {:association=>"contact"}
                            POST   /phone_numbers/:phone_number_id/links/contact(.:format)   phone_numbers#create_association {:association=>"contact"}
                            DELETE /phone_numbers/:phone_number_id/links/contact(.:format)   phone_numbers#destroy_association {:association=>"contact"}
              phone_numbers GET    /phone_numbers(.:format)                                  phone_numbers#index
                            POST   /phone_numbers(.:format)                                  phone_numbers#create
           new_phone_number GET    /phone_numbers/new(.:format)                              phone_numbers#new
          edit_phone_number GET    /phone_numbers/:id/edit(.:format)                         phone_numbers#edit
               phone_number GET    /phone_numbers/:id(.:format)                              phone_numbers#show
                            PATCH  /phone_numbers/:id(.:format)                              phone_numbers#update
                            PUT    /phone_numbers/:id(.:format)                              phone_numbers#update
                            DELETE /phone_numbers/:id(.:format)                              phone_numbers#destroy
```

##### `jsonapi_resource`

Like `jsonapi_resources`, but for resources you lookup without an id.

##### `jsonapi_links`

You can control the relationship URLs by passing a block into `jsonapi_resources` or `jsonapi_resource`. An empty block
will not create any relationship routes.

You can add relationship routes in with `jsonapi_links`, for example:

```
      jsonapi_resources :posts, except: [:destroy] do
        jsonapi_link :author, except: [:destroy]
        jsonapi_links :tags, only: [:show, :create]
      end

```

This will create relationship routes for author (show and create, but not destroy) and for tags (again show and create, but not destroy).

## Contributing

1. Fork it ( http://github.com/cerebris/jsonapi-resources/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

Copyright 2014 Cerebris Corporation. MIT License (see LICENSE for details).
