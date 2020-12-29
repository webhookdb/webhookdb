# frozen_string_literal: true

require "money"
require "monetize"
require "sequel"
require "sequel/model"

require "sequel/plugins/money_fields"

RSpec.describe Sequel::Plugins::MoneyFields, :db do
  context "with no fields given" do
    let(:model_class) do
      mc = create_model(:money_fields_test) do
        primary_key :id
        integer :money_cents
        text :money_currency
      end
      mc.plugin(:money_fields)
      mc
    end

    let(:model_object) { model_class.new }

    it "uses :money as the high-level accessor" do
      model_object.money = "$1800"
      expect(model_object.money).to be_a(Money)
      expect(model_object.money_cents).to eq(180_000)
      expect(model_object.money_currency).to eq("USD")

      model_object.money = {cents: 200, currency: "CAD"}
      expect(model_object.money_cents).to eq(200)
      expect(model_object.money_currency).to eq("CAD")

      model_object.money = OpenStruct.new(cents: 300, currency: "GBP")
      expect(model_object.money_cents).to eq(300)
      expect(model_object.money_currency).to eq("GBP")

      model_object.money = {"cents" => 400, "currency" => "EUR"}
      expect(model_object.money_cents).to eq(400)
      expect(model_object.money_currency).to eq("EUR")
    end
  end

  context "with fields set to 'rent' and 'deposit'" do
    let(:model_class) do
      mc = create_model(:money_fields_test) do
        primary_key :id
        integer :rent_cents
        text :rent_currency
        integer :deposit_cents
        text :deposit_currency
      end
      mc.plugin(:money_fields, :rent, :deposit)
      mc
    end

    let(:model_object) { model_class.new }

    it "provides high-level accessors for each column" do
      model_object.rent = 1250
      expect(model_object.rent).to be_a(Money)
      expect(model_object.rent.cents).to eq(125_000)
      expect(model_object.rent_cents).to eq(125_000)
      expect(model_object.rent_currency).to eq("USD")

      model_object.deposit = "CAD 82.50"
      expect(model_object.deposit).to be_a(Money)
      expect(model_object.deposit.cents).to eq(82_50)
      expect(model_object.deposit_cents).to eq(82_50)
      expect(model_object.deposit_currency).to eq("CAD")
    end
  end
end
