# frozen_string_literal: true

Sequel.migration do
  up do
    testmode = false

    run "LOCK TABLE organizations IN ACCESS EXCLUSIVE MODE"
    run "LOCK TABLE service_integrations IN ACCESS EXCLUSIVE MODE"

    # Migrate unencrypted columns to encrypted columns
    # without loading production models,
    # which we should never do for migrations.
    #
    # To do this, we can copy the raw value to a new column,
    # create a shim model with the column encryption plugin,
    # assign the encrypted column from the unencrypted version,
    # save, then drop the unencrypted columns,
    # leaving us with columns filled with the correct encrypted values.

    Sequel::Model.plugin :column_encryption do |enc|
      enc.key 0, Webhookdb::Postgres::Model.encryption_key_0
    end

    alter_table(:organizations) do
      add_column :readonly_connection_url_unenc, :text
      add_column :admin_connection_url_unenc, :text
    end
    from(:organizations).update(
      readonly_connection_url_unenc: :readonly_connection_url_raw,
      admin_connection_url_unenc: :admin_connection_url_raw,
      readonly_connection_url_raw: nil,
      admin_connection_url_raw: nil,
    )
    shim_org = Class.new(Sequel::Model(from(:organizations))) do
      plugin :column_encryption do |enc|
        enc.column :readonly_connection_url_raw
        enc.column :admin_connection_url_raw
      end
    end
    shim_org.each do |org|
      org.readonly_connection_url_raw = org.readonly_connection_url_unenc
      org.admin_connection_url_raw = org.admin_connection_url_unenc
      org.save_changes
    end
    alter_table(:organizations) do
      drop_column :readonly_connection_url_unenc
      drop_column :admin_connection_url_unenc
    end
    testmode && shim_org.each do |org|
      puts org.name
      puts "admin #{org.admin_connection_url_raw}"
      puts "readonly #{org.readonly_connection_url_raw}"
    end

    alter_table(:service_integrations) do
      add_column :webhook_secret_unenc, :text
      add_column :backfill_key_unenc, :text
      add_column :backfill_secret_unenc, :text
      set_column_allow_null :webhook_secret
      set_column_allow_null :backfill_key
      set_column_allow_null :backfill_secret
      set_column_default :webhook_secret, nil
      set_column_default :backfill_key, nil
      set_column_default :backfill_secret, nil
    end
    from(:service_integrations).update(
      webhook_secret_unenc: :webhook_secret,
      backfill_key_unenc: :backfill_key,
      backfill_secret_unenc: :backfill_secret,
      webhook_secret: nil,
      backfill_key: nil,
      backfill_secret: nil,
    )
    shim_sint = Class.new(Sequel::Model(from(:service_integrations))) do
      plugin :column_encryption do |enc|
        enc.column :webhook_secret
        enc.column :backfill_key
        enc.column :backfill_secret
      end
    end
    shim_sint.each do |sint|
      sint.webhook_secret = sint.webhook_secret_unenc
      sint.backfill_key = sint.backfill_key_unenc
      sint.backfill_secret = sint.backfill_secret_unenc
      sint.save_changes
    end
    alter_table(:service_integrations) do
      drop_column :webhook_secret_unenc
      drop_column :backfill_key_unenc
      drop_column :backfill_secret_unenc
    end
    testmode && shim_sint.each do |sint|
      puts "#{sint.opaque_id}: #{sint.webhook_secret} / #{sint.backfill_key} / #{sint.backfill_secret}"
    end
    raise "did not apply migration" if testmode
  end
end
