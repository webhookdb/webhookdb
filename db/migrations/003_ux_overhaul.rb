# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:customers) do
      add_column :opaque_id, :text, unique: true, null: true
    end
    from(:customers).each do |row|
      from(:customers).where(id: row[:id]).update(opaque_id: "cus_#{SecureRandom.hex(6)}")
    end
    alter_table(:customers) do
      set_column_not_null :opaque_id
    end
  end
  down do
    alter_table(:customers) do
      drop_column :opaque_id
    end
  end
end
