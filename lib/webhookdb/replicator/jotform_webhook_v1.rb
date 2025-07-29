# frozen_string_literal: true

class Webhookdb::Replicator::JotformWebhookV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "jotform_webhook_v1",
      ctor: self,
      feature_roles: [],
      resource_name_singular: "Jotform Webhook",
      supports_webhooks: true,
      supports_backfill: false,
      description: "Use this URL as a Jotform webhook to record and schematize all submissions to your form.",
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:event_id, TEXT, data_key: ["rawRequest", "event_id"])
  end

  def _denormalized_columns
    col = Webhookdb::Replicator::Column
    tsparse = col::IsomorphicProc.new(
      ruby: lambda do |s, **_|
        Time.at(s.to_i / 1000)
      end,
      sql: col::NOT_IMPLEMENTED,
    )
    return [
      col.new(:form_id, TEXT, data_key: "formID", index: true),
      col.new(:submission_id, TEXT, data_key: "submissionID", index: true),
      col.new(:submit_date, TIMESTAMP, data_key: ["rawRequest", "submitDate"], converter: tsparse, index: true),
      col.new(:build_date, TIMESTAMP, data_key: ["rawRequest", "buildDate"], converter: tsparse, index: true),
      col.new(:inserted_at, TIMESTAMP, optional: true, defaulter: :now, index: true),
      col.new(:questions, OBJECT),
    ]
  end

  def _timestamp_column_name = :submit_date
  def _update_where_expr = self.qualified_table_sequel_identifier[:submit_date] < Sequel[:excluded][:submit_date]

  def _resource_and_event(request)
    # If this is a multipart/form-data request, we need to parse it into something usable.
    needs_parsing = request.body.is_a?(String) && request.headers.fetch("content-type").include?("multipart/form-data")
    return [request.body, nil] unless needs_parsing
    env = {
      "CONTENT_TYPE" => request.headers.fetch("content-type"),
      "CONTENT_LENGTH" => request.body.bytesize.to_s,
      "rack.input" => StringIO.new(request.body),
    }
    body = Rack::Multipart.parse_multipart(env)
    return [body, nil]
  end

  def _prepare_for_insert(resource, event, request, enrichment)
    # The webhook is a form POST, there are JSON fields we need to parse out of it.
    req = Oj.load(resource.fetch("rawRequest"))
    resource["rawRequest"] = req
    resource["validatedNewRequiredFieldIDs"] = Oj.load(resource.fetch("validatedNewRequiredFieldIDs", "{}"))
    questions = {}
    # Top level keys can be q1_questionName
    req.keys.select { |k| question_key?(k) }.each do |k|
      questions[question_key(k)] = req.fetch(k)
    end
    # File uploads are different. The 'question key' is nested: {temp_upload: {q1_myimage: ['path.png#stuff']}}
    # But the actual answer (full url path) is top level: {myimage: ['https://jotform/uploads/xyz/path.png']}
    req.fetch("temp_upload", {}).each_key do |k|
      pure_key = question_key(k)
      questions[pure_key] = req.fetch(pure_key)
    end
    resource["questions"] = questions
    super
  end

  private def question_key?(s) = s =~ /^q\d+_/
  private def question_key(s) = s.gsub(/^q\d+_/, "")

  def _resource_to_data(resource, _event, _request, _enrichment)
    d = resource.dup
    d.delete("questions")
    return d
  end

  def _webhook_response(_request) = Webhookdb::WebhookResponse.ok

  def calculate_webhook_state_machine
    step = Webhookdb::Replicator::StateMachineStep.new
    step.output = %(To sync Jotform submissions to your database, go to your Form's Settings tab on the top,
Integration tab along the side, then choose the "Webhooks" integration.
Use this URL for your webhook:

  #{self.webhook_endpoint}

#{self._query_help_output})
    return step.completed
  end
end
