# Json::Api::Resources

## Initial Release 0.0.1

While this initial release is intended to meet the JSON API v1.0rc1 (https://github.com/json-api/json-api/pull/234) spec,
there are many features of the spec that it does not yet implement.

## Purpose

Out of the box JSON API Resources provides a framework to make an API server that supports the JSON API specification
through defining the resources that the API will serve. While this was designed primarily to use Rails, it should be
possible to use JAR with data not backed up by Active Record.

## Installation

Add this line to your application's Gemfile:

    gem 'json-api-resources'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install json-api-resources

## Usage

### Resources

Resources define the public interface to your API. A resource defines which attributes are exposed, as well as relationships
to other resources. In addition

Resource definitions should by convention be placed in a directory under app named resources, ```app/resources```. The
class name should be the single underscored name of the model that backs the resource with _resource.rb appended. For
Contacts this will be a file names contact_resource.rb with a class named ContactResource.

#### Derived from JSON::API::Resource

The resource must be derived from JSON::API::Resource, or a class that is itself derived from JSON::API::Resource.

For example:
```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
end
```

#### Attributes

For a resource to allow attributes to be accessed they must be declared. Single attributes can be declared using the
```attribute``` method, and multiple attributes can be declared with the ```attributes``` method on the resource class,
for example:

```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
  attribute :id
  attribute :name_first
  attributes :name_last, :email, :twitter
end
```

This resource has 5 attributes: :id, :name_first, :name_last, :email, :twitter. By default these attributes must exist
on the model that is handled by the Resource.

A resource object wraps a ruby object, usually an ActiveModel record, which is available as the @object variable. So
functions can also be defined on the resource that access the underlying object. For example a computed attribute for
full_name could be defined as such:

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

By default all attributes are assumed to be fetchable. The list of fetchable attributes can be filtered by overriding
the ```fetchable``` method. A contrived example that prevents the email from being returned for resources with an odd id:

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

The options flow through from the serializer. These can be used to pass in scope or other parameters. Note this method is 
called for each resource instance so you can use it to control the attributes on a per instance basis.

##### Creatable and Updateable Attributes

By default all attributes are assumed to be updateble and creatable. To prevent some attributes from being accepted by
the update or create methods you can override the ```self.updateable``` and ```self.creatable``` methods on a resource.
This example will prevent full_name from being set:

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

The options hash is not used by the ResourceController, but may be used if you override the controller methods.

#### Key

The primary key of the resource defaults to ```id```, but this can be changed using the ```key``` method.

```
class CurrencyResource < JSON::API::Resource
  key :code
  attributes :code, :name

  has_many :expense_entries
end

```

#### Model Name

The name of the underlying model is inferred from the Resource name. It can be overridden by use of the ```model_name```
method. For example:

```
class AuthorResource < JSON::API::Resource
  attributes :id, :name
  model_name 'Person'
  has_many :posts
end
```

#### Associations

Related resources need to be specified in the resource. These are declared with the ```has_one``` and the ```has_many```
methods. For example a simple case where a post has a single author and an author can have many posts:

```
class PostResource < JSON::API::Resource
  attribute :id, :title, :body

  has_one :author
end
```

and the corresponding author 

```
class AuthorResource < JSON::API::Resource
  attribute :id, :name

  has_many :posts
end
```

##### Options

The association methods support the following options:
 * class_name - a string specifying the underlying class for the related resource
 * primary_key - the primary key to the related resource, if different than ```id```
 * key - the key in the resource that identifies the related resource, if different than ```<resource_name>_id```
 * treat_as_set - allows the entire set of related records to be replaced in one operation. Defaults to false if not set.

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

Filters for locating objects of the resource type are specified in the resource definition. Single filters can be
declared using the ```filter``` method, and multiple filters can be declared with the ```filters``` method on the
resource class, for example:

```
require 'json/api/resource'

class ContactResource < JSON::API::Resource
  attributes :id, :name_first, :name_last, :email, :twitter

  filter :id
  filters :name_first, :name_last
end
```

##### Finders

Basic finding by filters is supported by resources. However if you have more complex requirements for finding you can 
override the ```find``` and the ```find_by_key``` methods on the resource.

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

JSON-API-Resources provides a class, ResourceController, that can be used as the base class for your controllers.
ResourceController supports index, show, create, update, and destroy methods. Just deriving your controller from
ResourceController will give you a fully functional controller. For example:

```
class PeopleController < JSON::API::ResourceController

end
```

Of course you are free to extend this as needed.

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

    RECORD_NOT_FOUND = 404
  end
end
```

These codes can be customized in your app by creating an initializer to override and or all of the codes.

### Serializer

The ResourceSerializer can be used to serialize a resource into JSON-API compliant JSON. ResourceSerializer has a serialize
method that takes a resource instance to serialize and a hash of options. For example:

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

There are options to control the output. The serializer takes the following options:

##### include
An array of resources. Nested resources can be specified with dot notation.
  Purpose: determines which objects will be side loaded with the source objects in a linked section
  Example: ```include: ['comments','author','comments.tags','author.posts']```
  
##### fields
A hash of resource types and arrays of fields for each resource type.
  Purpose: determines which fields are serialized for a resource type. This encompasses both attributes and
           association ids in the links section for a resource. Fields are global for a resource type.
  Example: ```fields: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}```

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
5. Create new Pull Request

## License

JSON::API::Resources is released under the [MIT License](http://www.opensource.org/licenses/MIT).