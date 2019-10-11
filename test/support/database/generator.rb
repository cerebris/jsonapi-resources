# In order to simplify testing of different ORMs and reduce differences in their schema
# generators, we use ActiveRecord::Schema to define our schema for readability and editing purposes.
# When running tests, all different ORMs (Sequel + ActiveRecord) will use the schema.sql to run
# their specs, ensuring a) a consistent test environment and b) easier adding of orms in the future.

require 'active_support'
require 'active_record'
require 'yaml'

ActiveSupport.eager_load!

connection_spec = YAML.load_file(File.expand_path('../../database/config.yml', __FILE__))["test"]

begin
  ActiveRecord::Base.establish_connection(connection_spec)

  ActiveRecord::Schema.verbose = false

  puts "Loading schema into #{connection_spec["database"]}"

  ActiveRecord::Schema.define do
    create_table :sessions, id: false, force: true do |t|
      t.string :id, :limit => 36, :primary_key => true, null: false
      t.string :survey_id, :limit => 36, null: false

      t.timestamps
    end

    create_table :responses, force: true do |t|
      #t.string :id, :limit => 36, :primary_key => true, null: false

      t.string :session_id, limit: 36, null: false

      t.string :type
      t.string :question_id, limit: 36

      t.timestamps
    end

    create_table :response_texts, force: true do |t|
      t.text :text
      t.integer :response_id

      t.timestamps
    end

    create_table :people, force: true do |t|
      t.string     :name
      t.string     :email
      t.datetime   :date_joined
      t.belongs_to :preferences
      t.integer    :hair_cut_id, index: true
      t.boolean    :book_admin, default: false
      t.boolean    :special, default: false
      t.timestamps null: false
    end

    create_table :author_details, force: true do |t|
      t.integer :person_id
      t.string  :author_stuff
      t.timestamps null: false
    end

    create_table :posts, force: true do |t|
      t.string     :title, length: 255
      t.text       :body
      t.integer    :author_id
      t.integer    :parent_post_id
      t.belongs_to :section, index: true
      t.timestamps null: false
    end

    create_table :comments, force: true do |t|
      t.text       :body
      t.belongs_to :post, index: true
      t.integer    :author_id
      t.timestamps null: false
    end

    create_table :companies, force: true do |t|
      t.string     :type
      t.string     :name
      t.string     :address
      t.timestamps null: false
    end

    create_table :tags, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :sections, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :posts_tags, force: true do |t|
      t.references :post, :tag, index: true
    end
    add_index :posts_tags, [:post_id, :tag_id], unique: true

    create_table :special_post_tags, force: true do |t|
      t.references :post, :tag, index: true
    end
    add_index :special_post_tags, [:post_id, :tag_id], unique: true

    create_table :comments_tags, force: true do |t|
      t.references :comment, :tag, index: true
    end

    create_table :iso_currencies, id: false, force: true do |t|
      t.string :code, limit: 3, null: false
      t.string :name
      t.string :country_name
      t.string :minor_unit
      t.timestamps null: false
    end
    add_index :iso_currencies, :code, unique: true

    create_table :expense_entries, force: true do |t|
      t.string :currency_code, limit: 3, null: false
      t.integer :employee_id, null: false
      t.decimal :cost, precision: 12, scale: 4, null: false
      t.date :transaction_date
      t.timestamps null: false
    end

    create_table :planets, force: true do |t|
      t.string :name
      t.string :description
      t.integer :planet_type_id
    end

    create_table :planets_tags, force: true do |t|
      t.references :planet, :tag, index: true
    end
    add_index :planets_tags, [:planet_id, :tag_id], unique: true

    create_table :planet_types, force: true do |t|
      t.string :name
    end

    create_table :moons, force: true do |t|
      t.string  :name
      t.string  :description
      t.integer :planet_id
      t.timestamps null: false
    end

    create_table :craters, id: false, force: true do |t|
      t.string  :code
      t.string  :description
      t.integer :moon_id
      t.timestamps null: false
    end

    create_table :preferences, force: true do |t|
      t.integer :person_id
      t.boolean :advanced_mode, default: false
      t.string  :nickname
      t.timestamps null: false
    end

    create_table :facts, force: true do |t|
      t.integer  :person_id
      t.string   :spouse_name
      t.text     :bio
      t.float    :quality_rating
      t.decimal  :salary, precision: 12, scale: 2
      t.datetime :date_time_joined
      t.date     :birthday
      t.time     :bedtime
      t.binary   :photo, limit: 1.kilobyte
      t.boolean  :cool
      t.timestamps null: false
    end

    create_table :books, force: true do |t|
      t.string :title
      t.string :isbn
      t.boolean :banned, default: false
      t.timestamps null: false
    end

    create_table :book_authors, force: true do |t|
      t.integer :book_id
      t.integer :person_id
    end

    create_table :book_comments, force: true do |t|
      t.text       :body
      t.belongs_to :book, index: true
      t.integer    :author_id
      t.boolean    :approved, default: true
      t.timestamps null: false
    end

    create_table :customers, force: true do |t|
      t.string   :name
      t.timestamps null: false
    end

    create_table :purchase_orders, force: true do |t|
      t.date     :order_date
      t.date     :requested_delivery_date
      t.date     :delivery_date
      t.integer  :customer_id
      t.string   :delivery_name
      t.string   :delivery_address_1
      t.string   :delivery_address_2
      t.string   :delivery_city
      t.string   :delivery_state
      t.string   :delivery_postal_code
      t.float    :delivery_fee
      t.float    :tax
      t.float    :total
      t.timestamps null: false
    end

    create_table :order_flags, force: true do |t|
      t.string :name
    end

    create_table :purchase_orders_order_flags, force: true do |t|
      t.references :purchase_order, :order_flag, index: true
    end
    add_index :purchase_orders_order_flags, [:purchase_order_id, :order_flag_id], unique: true, name: "po_flags_idx"

    create_table :line_items, force: true do |t|
      t.integer  :purchase_order_id
      t.string   :part_number
      t.string   :quantity
      t.float    :item_cost
      t.timestamps null: false
    end

    create_table :hair_cuts, force: true do |t|
      t.string :style
    end

    create_table :numeros_telefone, force: true do |t|
      t.string   :numero_telefone
      t.timestamps null: false
    end

    create_table :categories, force: true do |t|
      t.string :name
      t.string :status, limit: 10
      t.timestamps null: false
    end

    create_table :pictures, force: true do |t|
      t.string  :name
      t.integer :author_id
      t.references :imageable, polymorphic: true, index: true
      t.timestamps null: false
    end

    create_table :documents, force: true do |t|
      t.string  :name
      t.integer :author_id
      t.timestamps null: false
    end

    create_table :products, force: true do |t|
      t.string  :name
      t.integer :designer_id
      t.timestamps null: false
    end

    create_table :file_properties, force: true do |t|
      t.string :name
      #t.timestamps null: false
      t.references :fileable, polymorphic: true, index: true
      t.belongs_to :tag, index: true

      t.integer :size
    end

    create_table :vehicles, force: true do |t|
      t.string :type
      t.string :make
      t.string :model
      t.string :length_at_water_line
      t.string :drive_layout
      t.string :serial_number
      t.integer :person_id
      t.timestamps null: false
    end

    create_table :makes, force: true do |t|
      t.string :model
      t.timestamps null: false
    end

    # special cases - fields that look like they should be reserved names
    create_table :hrefs, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :links, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :web_pages, force: true do |t|
      t.string :href
      t.string :link
      t.timestamps null: false
    end

    create_table :questionables, force: true do |t|
      t.timestamps null: false
    end

    create_table :boxes, force: true  do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :things, force: true  do |t|
      t.string :name
      t.references :user
      t.references :box

      t.timestamps null: false
    end

    create_table :users, force: true  do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :related_things, force: true  do |t|
      t.string :name
      t.references :from, references: :thing
      t.references :to, references: :thing

      t.timestamps null: false
    end

    create_table :questions, force: true do |t|
      t.string :text
      t.timestamps null: false
    end

    create_table :answers, force: true do |t|
      t.references :question
      t.integer :respondent_id
      t.string  :respondent_type
      t.string :text
      t.timestamps null: false
    end

    create_table :patients, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :doctors, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :painters, force: true do |t|
      t.string :name

      t.timestamps null: false
    end

    create_table :paintings, force: true do |t|
      t.string :title
      t.string :category
      t.belongs_to :painter

      t.timestamps null: false
    end

    create_table :collectors, force: true do |t|
      t.string :name
      t.belongs_to :painting
    end

    create_table :lists, force: true do |t|
      t.string :name
    end

    create_table :list_items, force: true do |t|
      t.belongs_to :list
    end

    # special cases
    create_table :storages, force: true do |t|
      t.string :token, null: false
      t.string :name
      t.timestamps null: false
    end

    create_table :keepers, force: true do |t|
      t.string :name
      t.string :keepable_type, null: false
      t.integer :keepable_id, null: false
      t.timestamps null: false
    end

    create_table :access_cards, force: true do |t|
      t.string :token, null: false
      t.string :security_level
      t.timestamps null: false
    end

    create_table :workers, force: true do |t|
      t.string :name
      t.integer :access_card_id, null: false
      t.timestamps null: false
    end

    create_table :agencies, force: true do |t|
      t.string :name
      t.timestamps null: false
    end

    create_table :indicators, force: true do |t|
      t.string :name
      t.string :import_id
      t.integer :agency_id, null: false
      t.timestamps null: false
    end

    create_table :widgets, force: true do |t|
      t.string :name
      t.string :indicator_import_id, null: false
      t.timestamps null: false
    end

    create_table :robots, force: true do |t|
      t.string :name
      t.integer :version
      t.timestamps null: false
    end
  end

  class FixtureGenerator
    include ActiveRecord::TestFixtures
    self.fixture_path = File.expand_path('../fixtures', __FILE__)
    fixtures :all

    def self.load_fixtures
      require_relative '../inflections'
      require_relative '../active_record/models'
      ActiveRecord::Base.connection.disable_referential_integrity do
        FixtureGenerator.new.send(:load_fixtures, ActiveRecord::Base)
      end
    end
  end

  puts "Loading fixture data into #{connection_spec["database"]}"

  FixtureGenerator.load_fixtures

  puts "Dumping data into data.sql"

  File.open(File.expand_path('../dump.sql', __FILE__), "w") do |f|
    `sqlite3 test_db .tables`.split(/\s+/).each do |table_name|
      f << %{DROP TABLE IF EXISTS "#{table_name}";\n}
      puts "Dumping data from #{table_name}..."
    f << `sqlite3 #{connection_spec["database"]} ".dump #{table_name}"`
    end.join("\n")
    f << "PRAGMA foreign_keys=ON;" # reenable foreign_keys
  end

  puts "Done!"
ensure
  File.delete(connection_spec["database"]) if File.exists?(connection_spec["database"])
end
