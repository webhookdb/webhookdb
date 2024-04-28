# frozen_string_literal: true

module Webhookdb::Admin
  module Linked
    protected def _admin_datatype = self.class.dataset.first_source_table
    protected def _admin_id = self.pk
    protected def _admin_display = "show"
    def admin_link = "#{Webhookdb.admin_url}/admin#/#{_admin_datatype}/#{_admin_id}/#{_admin_display}"
  end
end
