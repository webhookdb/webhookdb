# frozen_string_literal: true

require "appydays/configurable"
require "liquid"

module Webhookdb::Messages
end

module Webhookdb::Liquid
end

module Webhookdb::Message
  include Appydays::Configurable
  extend Webhookdb::MethodUtilities

  require "webhookdb/liquid/expose"
  require "webhookdb/liquid/filters"
  require "webhookdb/liquid/liquification"
  require "webhookdb/liquid/partial"

  require "webhookdb/message/email_transport"
  require "webhookdb/message/fake_transport"
  require "webhookdb/message/transport"
  require "webhookdb/message/liquid_drops"
  require "webhookdb/message/template"

  DEFAULT_TRANSPORT = :email
  DATA_DIR = Webhookdb::DATA_DIR + "messages"

  configurable(:messages) do
    after_configured do
      Liquid::Environment.default.error_mode = :strict
      Liquid::Environment.default.file_system = Liquid::LocalFileSystem.new(DATA_DIR, "%s.liquid")
    end
  end

  # Create a Webhookdb::Message::Delivery ready to deliver (rendered, all bodies set up)
  # using the given transport_type to the given user.
  def self.dispatch(template, to, transport_type)
    (transport = Webhookdb::Message::Transport.for(transport_type)) or
      raise InvalidTransportError, "Invalid transport #{transport_type}"
    recipient = transport.recipient(to)

    contents = self.render(template, transport_type, recipient)

    Webhookdb::Message::Delivery.db.transaction do
      delivery = Webhookdb::Message::Delivery.create(
        template: template.full_template_name,
        transport_type: transport.type,
        transport_service: transport.service,
        to: recipient.to,
        recipient: recipient.customer,
        extra_fields: template.extra_fields,
      )
      transport.add_bodies(delivery, contents)
      delivery.publish_deferred("dispatched", delivery.id)
      return delivery
    end
  end

  # Render the transport-specific version of the given template
  # and return a the rendering (content and exposed variables).
  #
  # Templates can expose data to the caller by using the 'expose' tag,
  # like {% expose subject %}Hello from Webhookdb!{% endexpose %}.
  # This is available as [:subject] on the returned rendering.
  def self.render(template, transport_type, recipient)
    template_file = template.template_path(transport_type)
    raise MissingTemplateError, "#{template_file} does not exist" unless template_file.exist?

    drops = template.liquid_drops.stringify_keys.merge(
      "recipient" => Webhookdb::Message::CustomerDrop.new(recipient),
      "environment" => Webhookdb::Message::EnvironmentDrop.new,
      "app_url" => Webhookdb.app_url,
    )
    drops = self.unify_drops_encoding(drops)

    content_tmpl = Liquid::Template.parse(template_file.read)
    # The 'expose' drop smashes data into the register.
    # We need to keep track of the register to get the subject back out,
    # so we need to make our own context.
    lctx = Liquid::Context.new(
      [drops, content_tmpl.assigns],
      content_tmpl.instance_assigns,
      content_tmpl.registers,
      true,
      content_tmpl.resource_limits,
    )
    content = content_tmpl.render!(lctx, strict_variables: true)

    transport = Webhookdb::Message::Transport.for(transport_type)
    if transport.supports_layout?
      layout_file = template.layout_path(transport_type)
      if layout_file
        raise MissingTemplateError, "#{template_file} does not exist" unless layout_file.exist?
        layout_tmpl = Liquid::Template.parse(layout_file.read)
        drops["content"] = content.dup
        content = layout_tmpl.render!(drops, strict_variables: true, registers: content_tmpl.registers)
      end
    end

    return Rendering.new(content, lctx.registers)
  end

  # Handle encoding in liquid drop string values that would likely crash message rendering.
  #
  # If there is a mixed character encoding of string values in a liquid drop,
  # such as when handling user-supplied values, force all strings into UTF-8.
  #
  # This is needed because the way Ruby does encoding coercion when parsing input
  # which does not declare an encoding, such as a file or especially an HTTP response.
  # Ruby will:
  # - Use ASCII if the values fit into 7 bits
  # - Use ASCII-8BIT if the values fit into 8 bits (128 to 255)
  # - Otherwise, use UTF-8.
  #
  # The actual rules are more complex, but this is common enough.
  #
  # While ASCII encoding can be used as UTF-8, ASCII-8BIT cannot.
  # So adding `(ascii-8bit string) + (utf-8 string)` will error with an
  # `Encoding::CompatibilityError`.
  #
  # Instead, if we see a series of liquid drop string values
  # with different encodings, force them all to be UTF-8.
  # This can result in some unexpected behavior,
  # but it should be fine, since you'd only see it with unexpected input
  # (all valid inputs should be UTF-8).
  #
  # @param [Hash] drops
  # @return [Hash]
  def self.unify_drops_encoding(drops)
    return drops if drops.empty?
    seen_enc = nil
    force_enc = false
    drops.each_value do |v|
      next unless v.respond_to?(:encoding)
      seen_enc ||= v.encoding
      next if seen_enc == v.encoding
      force_enc = true
      break
    end
    return drops unless force_enc
    utf8 = Encoding.find("UTF-8")
    result = drops.each_with_object({}) do |(k, v), memo|
      if v.respond_to?(:encoding) && v.encoding != utf8
        v2 = v.encode(utf8, invalid: :replace, undef: :replace, replace: "?")
        memo[k] = v2
      else
        memo[k] = v
      end
    end
    return result
  end

  def self.send_unsent
    Webhookdb::Message::Delivery.unsent.each(&:send!)
  end

  class InvalidTransportError < Webhookdb::ProgrammingError; end

  class MissingTemplateError < Webhookdb::ProgrammingError; end

  # Presents a homogeneous interface for a given 'to' value (email vs. customer, for example).
  # .to will always be a plain object, and .customer will be a +Webhookdb::Customer+ if present.
  class Recipient
    attr_reader :to, :customer

    def initialize(to, customer)
      @to = to
      @customer = customer
    end
  end

  # String-like type representing the output of a rendering operation.
  # Use [key] to access exposed variables, as per +LiquidExpose+.
  class Rendering
    attr_reader :contents, :exposed

    def initialize(contents, exposed={})
      @contents = contents
      @exposed = exposed
    end

    def [](key)
      return self.exposed[key]
    end

    def to_s
      return self.contents
    end

    def respond_to_missing?(name, *args)
      return true if super
      return self.contents.respond_to?(name)
    end

    def method_missing(name, *, &)
      return self.contents.respond_to?(name) ? self.contents.send(name, *, &) : super
    end
  end
end
