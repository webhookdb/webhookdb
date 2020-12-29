# frozen_string_literal: true

require "money"
require "monetize"

require "sequel"
require "sequel/model"

# Plugin for adding money fields to a model.
#
# == Example
#
# Define a model with money values:
#
#   class ACME::Property < Sequel::Model(:properties)
#
#       plugin :money_fields, :rent
#
# And in the schema:
#
#   create_table( :properties ) do
#       primary_key :id
#       bigint :rent_cents, null: false
#       text :rent_currency, null: false, default: 'USD'
#   end
#
# And used as follows:
#
#   property = ACME::Property.new(rent: Monetize.parse('$5'))
#   property.rent_cents # 500
#   property.rent # Money object presenting 5 USD
#
# Each money field you declare requires two columns: an integer(ish) column that
# will store the fractional amount called "#{field}_cents", and a text(ish)
# column for storing the currency name called "#{field}_currency".
#
# The plugin generates methods for getting and setting each field. The setter
# automatically parses the input using the 'monetize' gem into a Money object,
# and the getter creates a new Money object from the two columns and returns it.
#
# If you don't give at least one column to the plugin declaration, the field
# will be assumed to be called 'money'.
#
# See the docs for Money and Monetize for details on what you can do with the
# Money objects these fields use.
#
module Sequel::Plugins::MoneyFields
  def self.configure(model, *args)
    args << :money if args.empty?

    args.flatten.each do |field|
      reader = self.make_money_reader(field)
      writer = self.make_money_writer(field)

      model.send(:define_method, field.to_s, reader)
      model.send(:define_method, "#{field}=", writer)
    end
  end

  # Return a Proc that can serve as the method body for the Money amount
  # reader for the given +field+.
  def self.make_money_reader(field)
    cents_column = "#{field}_cents".to_sym
    currency_column = "#{field}_currency".to_sym

    return lambda do
      Money.new(self[cents_column], self[currency_column])
    end
  end

  # Return a Proc that can serve as the method body for the Money amount
  # writer for the given +field+.
  def self.make_money_writer(field)
    cents_column = "#{field}_cents".to_sym
    currency_column = "#{field}_currency".to_sym

    return lambda do |value|
      if value.respond_to?(:cents) && value.respond_to?(:currency)
        money = Money.new(value.cents, value.currency)
      else
        begin
          cents = value[:cents] || value["cents"]
          cur = value[:currency] || value["currency"]
          money = Money.new(cents, cur)
        rescue TypeError, NoMethodError
          money = Monetize.parse!(value)
        end
      end
      self[cents_column] = money.cents.to_i
      self[currency_column] = money.currency
    end
  end
end
