## Conventions

When defining columns, options should be "null", "unique", "default":

`column_type :column_name[, null: false][, unique: true][, default:'value']`

Timestamp plugin columns (created, updated, soft delete) should always be:

```ruby
timestamptz :created_at, null: false, default: 'now()'
timestamptz :updated_at
timestamptz :soft_deleted_at
``` 

Money columns should always be:

```ruby
integer :price_cents, null: false, default: 0
text :price_currency, null: false, default: 'USD'
```

Foreign key columns should almost always be non-null,
and should usually get an index or unique constraint:

```ruby
foreign_key :product_id, :products, null: false
index :product_id
```

Prefer non-null columns, especially for strings (and other primitives),
and almost always for numbers and booleans.
There are many reasons for this, all religious, which I'll happily preach to you.

In this example, `:name` is non-null but has no default,
because we expect the application to always require it.
`:description` is a less important field so we can give it a default of empty string.
For even more integrity, we could put constraints on the `name` column,
but we don't need to do that yet.

```ruby
text :name, null: false
text :description, null: false, default: ''
```

Put indices and constraints (unique and otherwise) near their column.
Put compound indices/constraints at the bottom of the block.

```ruby
foreign_key :customer_id, :customers, null: false
index :customer_id
foreign_key :address_id, :addresses, null: false

unique [:customer_id, :address_id]
```

## Useful References

- http://sequel.jeremyevans.net/rdoc/files/doc/migration_rdoc.html
- https://github.com/jeremyevans/sequel/blob/master/doc/schema_modification.rdoc
