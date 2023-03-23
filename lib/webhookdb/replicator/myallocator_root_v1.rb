# frozen_string_literal: true

class Webhookdb::Replicator::MyallocatorRootV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::BookingpalV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "myallocator_root_v1",
      ctor: ->(sint) { Webhookdb::Replicator::MyallocatorRootV1.new(sint) },
      feature_roles: ["myallocator"],
      resource_name_singular: "MyAllocator Root",
      resource_name_plural: "MyAllocator Root",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:ignore_id, INTEGER)
  end

  def _denormalized_columns
    return []
  end

  def _upsert_webhook(**_kwargs)
    raise NotImplementedError("This is a stub integration only for auth and url routing purposes.")
  end

  def _fetch_backfill_page(*)
    return [], nil
  end

  def webhook_response(_request)
    raise NotImplementedError("This is a stub integration only for auth and url routing purposes.")
  end

  def calculate_create_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    unless self.service_integration.webhook_secret.present?
      step.output = %(In order to authenticate information recieved from BookingPal, we will need a webhook secret.)
      return step.prompting("webhook secret").webhook_secret(self.service_integration)
    end
    step.output = %(WebhookDB will pass this authentication information on to dependents.
    )
    return step.completed
  end

  def clear_create_information
    self.service_integration.update(webhook_secret: "")
  end

  def calculate_backfill_state_machine
    return self.calculate_create_state_machine
  end

  def clear_backfill_information
    self.clear_create_information
  end

  # TODO: abstract this, it's repeated code
  def get_dependent_integration(service_name)
    sints = self.service_integration.dependents.filter { |si| si.service_name == service_name }
    raise Webhookdb::InvalidPrecondition, "there is no #{service_name} integration in dependents" if sints.empty?
    if sints.length > 1
      raise Webhookdb::InvalidPrecondition,
            "there are multiple #{service_name} integrations in dependents"
    end
    # only return the integration if it is the only one of its kind in full dependents list
    return sints.first
  end

  def dispatch_request_to(request)
    sint = nil
    case request.path
      when /BookingCreate/, /GetBookingList/, /GetBookingId/
        sint = self.get_dependent_integration("myallocator_booking_v1")
      when /CreateProperty/
        sint = self.get_dependent_integration("myallocator_property_v1")
      when /SetupProperty/, /GetRoomTypes/
        sint = self.get_dependent_integration("myallocator_room_v1")
    else
        raise NotImplementedError
    end
    return sint.replicator
  end
end
