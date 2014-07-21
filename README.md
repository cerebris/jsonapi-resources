# JSON::API::Resources

JSON::API::Resources, or "JAR", provides a framework for developing a server that complies with the [JSON API](http://jsonapi.org/) specification.

Like JSON API itself, JAR's design is focused on the resources served by an API. JAR needs little more than a definition of your resources, including their attributes and relationships, to make your server compliant with JSON API.

While designed primarily to use Rails, it is possible to use JAR with data not backed by ActiveRecord.

## Status

The JSON API specification is close to a [1.0rc1 release](https://github.com/json-api/json-api/pull/237) but is still in flux. JAR follows many aspects of the spec but is not yet a complete implementation.

## Installation

Add JAR to your application's `Gemfile`:

    gem 'json-api-resources'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install json-api-resources

## Usage

### Resources

Resources define the public interface to your API. A resource defines which attributes are exposed, as well as relationships to other resources.

Resource definitions should by convention be placed in a directory under app named resources, `app/resources`. The class name should be the single underscored name of the model that backs the resource with `_resource.rb` appended. For example, a `Contact` model's resource should have a class named `ContactResource` defined in a file named `contact_resource.rb`.

#### JSON::API::Resource

Resources must be derived from `JSON::API::Resource`, or a class that is itself derived from `JSON::API::Resource`.

For example:

```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
end
```

#### Attributes

Any of a resource's attributes that are accessible must be explicitly declared. Single attributes can be declared using the `attribute` method, and multiple attributes can be declared with the `attributes` method on the resource class.

For example:

```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
  attribute :id
  attribute :name_first
  attributes :name_last, :email, :twitter
end
```

This resource has 5 attributes: `:id`, `:name_first`, `:name_last`, `:email`, `:twitter`. By default these attributes must exist on the model that is handled by the resource.

A resource object wraps a Ruby object, usually an ActiveModel record, which is available as the `@object` variable. This allows a resource's methods to access the underlying object. 

For example, a computed attribute for `full_name` could be defined as such:

```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
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
class AuthorResource < JSON::API::Resource
  attributes :id, :name, :email
  model_name 'Person'
  has_many :posts

  def fetchable(keys, options = {})
    if (@object.id % 2) == 1
      super(keys - [:email])
    else
      super(keys)
    end
  end

end
```

Options flow through from objects that use resources, such as the serializer. These can be used to pass in scope or other parameters. Because this method is called for each resource instance, you can use it to control the attributes on a per instance basis.

##### Creatable and Updateable Attributes

By default all attributes are assumed to be updateble and creatable. To prevent some attributes from being accepted by the `update` or `create` methods, override the `self.updateable` and `self.creatable` methods on a resource.

This example prevents `full_name` from being set:

```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
  attributes :id, :name_first, :name_last, :email, :twitter
  attribute :full_name

  def full_name
    "#{@object.name_first}, #{@object.name_last}"
  end

  def self.updateable(keys, options = {})
    super(keys - [:full_name])
  end

  def self.createable(keys, options = {})
    super(keys - [:full_name])
  end
end
```

The options hash is not used by the `ResourceController`, but may be used if you override the controller methods.

#### Key

The primary key of the resource defaults to `id`, which can be changed using the `key` method.

```
class CurrencyResource < JSON::API::Resource
  key :code
  attributes :code, :name

  has_many :expense_entries
end

```

#### Model Name

The name of the underlying model is inferred from the Resource name. It can be overridden by use of the `model_name` method. For example:

```
class AuthorResource < JSON::API::Resource
  attributes :id, :name
  model_name 'Person'
  has_many :posts
end
```

#### Associations

Related resources need to be specified in the resource. These are declared with the `has_one` and the `has_many` methods. 

Here's a simple example where a post has a single author and an author can have many posts:

```
class PostResource < JSON::API::Resource
  attribute :id, :title, :body

  has_one :author
end
```

And the corresponding author:

```
class AuthorResource < JSON::API::Resource
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
 class CommentResource < JSON::API::Resource
  attributes :id, :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags, treat_as_set: true
 end
```

```
class ExpenseEntryResource < JSON::API::Resource
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
require 'json/api/resource'

class ContactResource < JSON::API::Resource
  attributes :id, :name_first, :name_last, :email, :twitter

  filter :id
  filters :name_first, :name_last
end
```

##### Finders

Basic finding by filters is supported by resources. However if you have more complex requirements for finding you can override the `find` and `find_by_key` methods on the resource.

Here's a hackish example:

```
class AuthorResource < JSON::API::Resource
  attributes :id, :name
  model_name 'Person'
  has_many :posts

  filter :name

  def self.find(attrs, options = {})
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

JSON::API::Resources provides a class, `ResourceController`, that can be used as the base class for your controllers. `ResourceController` supports `index`, `show`, `create`, `update`, and `destroy` methods. Just deriving your controller from `ResourceController` will give you a fully functional controller. 

For example:

```
class PeopleController < JSON::API::ResourceController

end
```

Of course you are free to extend this as needed.

##### find_options

The ResourceController has an overridable method called ```find_options```. This gives you a place to set options to be 
passed into the finder calls made by the ResourceController. For example:

```
  def find_options
    {current_user: current_user}
  end
```

find_options are not used by the default ```find``` method, however they are available in ```find``` and the
```find_by_key``` overrides.

##### serialize_options

The ResourceController has an overridable method called ```serialize_options```. This gives you a place to set options to be 
passed into the serializer calls made by the ResourceController. For example:

```
  def serialize_options
    {current_user: current_user}
  end
```

#### Error codes

Error codes are provided for each error object returned, based on the error. These errors are:

```
module JSON
  module API
    VALIDATION_ERROR = 100
    INVALID_RESOURCE = 101
    FILTER_NOT_ALLOWED = 102
    INVALID_FIELD_VALUE = 103
    INVALID_FIELD = 104
    PARAM_NOT_ALLOWED = 105
    INVALID_FILTER_VALUE = 106

    RECORD_NOT_FOUND = 404
  end
end
```

These codes can be customized in your app by creating an initializer to override any or all of the codes.

### Serializer

The `ResourceSerializer` can be used to serialize a resource into JSON API compliant JSON. `ResourceSerializer` has a `serialize` method that takes a resource instance to serialize and a hash of options. For example:

```
post = Post.find(1)
JSON::API::ResourceSerializer.new.serialize(PostResource.new(post))
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

#### Serializer options

Options can be specified to control a serializer's output. Serializers take the following options:

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
JSON::API::ResourceSerializer.new.serialize(PostResource.new(post),
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

## Contributing

1. Fork it ( http://github.com/cerebris/json-api-resources/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

Copyright 2014 Cerebris Corporation. MIT License (see LICENSE for details).
