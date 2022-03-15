# frozen_string_literal: true

Sequel.migration do
  up do
    from(:organization_memberships).where(invitation_code: nil).update(invitation_code: "")
    alter_table(:organization_memberships) do
      add_column :is_default, :boolean, null: false, default: false
      set_column_default :invitation_code, ""
      set_column_not_null :invitation_code
      set_column_default :verified, nil
      set_column_not_null :membership_role_id
      drop_column :status
      add_index(
        [:customer_id, :organization_id],
        name: :one_default_per_customer,
        unique: true,
        where: {is_default: true},
      )
      add_constraint(
        :default_is_verified,
        (Sequel[is_default: true] & Sequel[verified: true]) | Sequel[is_default: false],
      )
      add_constraint(
        :invited_has_code,
        (Sequel[verified: true] & Sequel.expr { length(invitation_code) < 1 }) |
          (Sequel[verified: false] & Sequel.expr { length(invitation_code) > 0 }),
      )
    end
  end
end
