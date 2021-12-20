# frozen_string_literal: true

Sequel.migration do
  up do
    create_join_table({role_id: :roles, organization_id: :organizations},
                      name: :feature_roles_organizations,)

    # Move away from using OrganizationRole, use Generalized Role table instead
    alter_table(:organization_memberships) do
      add_foreign_key :membership_role_id, :roles
    end

    from(:organization_roles).each do |row|
      # first create the new role--if the new role name violates the uniqueness constraint on names,
      # we can use the existing role and have the meaning change depending on context
      from(:roles).insert_conflict.insert(name: row[:name])

      # now update :organization_memberships with the new foreign key value
      new_role = from(:roles).where(name: row[:name]).first
      from(:organization_memberships).where(role_id: row[:id]).update(membership_role_id: new_role[:id])
    end

    alter_table(:organization_memberships) do
      drop_foreign_key :role_id
    end

    drop_table(:organization_roles)
  end
end
