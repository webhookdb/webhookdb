# frozen_string_literal: true

# Write docs for docs.webhookdb.com Jekyll site.
class Webhookdb::Replicator::Docgen
  def self.documentable_descriptors
    return Webhookdb::Replicator.registry.values.reject do |repl|
      repl.name.start_with?("webhookdb_", "fake_")
    end.sort_by(&:name)
  end

  # @!attribute desc
  #   @return [Webhookdb::Replicator::Descriptor]
  attr_reader :desc
  attr_reader :lines

  # @param desc [Webhookdb::Replicator::Descriptor]
  def initialize(desc)
    @desc = desc
    @lines = []
    @documentable_descriptors = self.class.documentable_descriptors
  end

  def sint
    @sint ||= Webhookdb::ServiceIntegration.new(
      service_name: desc.name,
      opaque_id: "svi_fixture",
      table_name: desc.name + "_fixture",
    )
  end

  def repl
    @repl ||= desc.ctor[sint]
  end

  def markdown
    _frontmatter
    _intro
    _features
    _schema
    _tabledef
    _prevnext
    return lines.join("\n")
  end

  def _frontmatter
    lines << "---"
    lines << "title: #{desc.resource_name_singular}"
    lines << "layout: home"
    idx = @documentable_descriptors.index(desc)
    lines << "nav_order: #{(idx + 1) * 10}"
    lines << "---"
    lines << ""
  end

  def _intro
    lines << "# #{desc.resource_name_singular} (`#{desc.name}`)"
    if desc.description.present?
      lines << ""
      lines << desc.description
    end
    if desc.api_docs_url.present?
      lines << ""
      lines << "Docs for this API: [#{desc.api_docs_url}](#{desc.api_docs_url})"
    end
    lines << ""
  end

  def _features
    lines << "## Features"
    lines << ""
    lines << "<dl>"
    if (dep = desc.dependency_descriptor)
      lines << "<dt>Depends on</dt>"
      lines << "<dd>To use this replicator, you will need #{refanchor(dep)}. " \
               "You'll be prompted to create it if you haven't.</dd>"
      lines << ""
    end
    deps = @documentable_descriptors.select { |d| d.dependency_descriptor == desc }
    if deps.any?
      lines << "<dt>Dependents</dt>"
      lines << "<dd>This replicator is required for the creation of the following dependents:"
      lines << "<ul>"
      deps.each { |d| lines << "<li>#{refanchor(d)}</li>" }
      lines << "</ul>"
      lines << "</dd>"
      lines << ""
    end
    lines << "<dt>Supports Webhooks</dt>"
    lines << "<dd>#{boolmoji(desc.supports_webhooks?)}</dd>"
    lines << "<dt>Supports Backfilling</dt>"
    lines << "<dd>#{boolmoji(desc.supports_backfill?)}</dd>"
    if desc.enterprise?
      lines << "<dt>Enterprise Only</dt>"
      lines << "<dd>Yes</dd>"
    end
    lines << ""
    lines << "</dl>"
    lines << ""
  end

  def _schema
    lines << "## Schema"
    lines << ""
    lines << "Tables replicated from #{desc.resource_name_plural} have this schema.
Note that the data types listed are for Postgres;
when [replicating to other databases]({% link _concepts/replication_databases.md %}),
other data types maybe used."
    lines << ""
    lines << "| Column | Type | Indexed |"
    columns = [repl.primary_key_column, repl.remote_key_column]
    columns.concat(repl.storable_columns)
    columns << repl.data_column
    columns.each do |c|
      name = "`#{c.name}`"
      (name += "*") if c.name == :data
      lines << "| #{name} | `#{pgtype(c.type)}` | #{truecheck(c.index)} |"
    end
    lines << ""
    lines << <<~S
      <span class="fs-3">* The `data` column contains the raw payload from the webhook or API.
      In many cases there is no canonical form, like if a webhook and API request return
      two different versions of the same resource.
      In that case we try to keep the most coherent and detailed resource."</span>
    S
  end

  def _tabledef
    lines << "## Table definition"
    lines << ""
    lines << "This definition can also be generated through `webhookdb fixture #{desc.name}`."
    lines << ""
    lines << "```sql"
    lines << repl.create_table_modification.to_s
    lines << "```"
    lines << ""
  end

  def _prevnext
    idx = @documentable_descriptors.index(desc)
    raise Webhookdb::InvariantViolation if idx.nil?
    prevtxt = nexttxt = ""
    if (rprev = idx.zero? ? nil : @documentable_descriptors[idx - 1])
      prevtxt = "prev='_integrations/#{rprev.name}.md' prevLabel='#{rprev.name}' "
    end
    if (rnext = idx == (@documentable_descriptors.size - 1) ? nil : @documentable_descriptors[idx + 1])
      nexttxt = "next='_integrations/#{rnext.name}.md' nextLabel='#{rnext.name}'"
    end
    lines << "{% include prevnext.html #{prevtxt}#{nexttxt} %}"
    lines << ""
  end

  def refhref(d) = "{% link _integrations/#{d.name}.md %}"
  def refanchor(d) = "<a href=\"#{refhref(d)}\">#{d.name}</a>"
  def boolmoji(b) = b ? "✅" : "❌"
  def truecheck(b) = b ? "✅" : ""
  def pgtype(t) = Webhookdb::DBAdapter::PG::COLTYPE_MAP[t]

  def self.replicator_list_md(descriptors)
    lines = []
    descriptors.each do |d|
      line = "- [#{d.resource_name_singular}]({% link _integrations/#{d.name}.md %})"
      line += " ([Enterprise]({% link docs/enterprise.md %}) only)" if d.enterprise
      lines << line
    end
    return lines.join("\n")
  end
end
