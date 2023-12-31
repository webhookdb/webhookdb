# frozen_string_literal: true

require "webhookdb/api"

class Webhookdb::API::Replay < Webhookdb::API::V1
  DEFAULT_INTERVAL = 1.hour

  resource :organizations do
    route_param :org_identifier, type: String do
      resource :replay do
        params do
          optional :before, type: Time
          optional :after, type: Time
          optional :hours, type: Integer
          optional :service_integration_identifier
        end
        post do
          current_customer
          org = lookup_org!
          cutoff_lower = params[:after]
          cutoff_upper = params[:before]
          interval = params.fetch(:hours, 0).positive? ? params[:hours].hours : DEFAULT_INTERVAL
          if cutoff_lower.nil? && cutoff_upper.nil?
            cutoff_upper = Time.now.utc
            cutoff_lower = cutoff_upper - interval
          elsif cutoff_lower && cutoff_upper
            nil
          elsif cutoff_upper
            cutoff_lower = cutoff_upper - interval
          elsif cutoff_lower
            # Add an offset so that cutoff_upper is in the same timezone as cutoff_lower
            cutoff_upper = cutoff_lower + (Time.now - cutoff_lower)
          end

          old_age_cutoff = Time.now - Webhookdb::LoggedWebhook.maximum_replay_history_hours.hours
          merror!(400, "Webhooks older than #{old_age_cutoff.utc} cannot be replayed.") if cutoff_upper < old_age_cutoff

          max_replay_hours = Webhookdb::LoggedWebhook.maximum_replay_interval_hours
          if (cutoff_upper - cutoff_lower) > max_replay_hours.hours
            merror!(400, "The maximum webhook replay interval is #{max_replay_hours} hours.")
          end

          ds = Webhookdb::LoggedWebhook.where(organization_id: org.id).
            where { inserted_at >= cutoff_lower }.
            where { inserted_at <= cutoff_upper }.
            where(truncated_at: nil).select(:id)
          if params[:service_integration_identifier].present?
            sint = lookup_service_integration!(org, params[:service_integration_identifier])
            ds = ds.where(service_integration_opaque_id: sint.opaque_id)
          end
          replayed = 0
          ds.paged_each do |lw|
            lw.replay_async
            replayed += 1
          end
          s = replayed == 1 ? "" : "s"
          message = "Replaying #{replayed} webhook#{s} between #{cutoff_lower.iso8601} and #{cutoff_upper.iso8601}."
          status 200
          present({}, with: Webhookdb::API::BaseEntity, message:)
        end
      end
    end
  end
end
