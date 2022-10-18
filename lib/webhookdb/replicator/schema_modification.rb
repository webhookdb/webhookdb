# frozen_string_literal: true

class Webhookdb::Replicator::SchemaModification
  # All of these statements can be sent to the server at once.
  # @return [Array<String>]
  attr_reader :transaction_statements
  # Each of these statements must be executed one-at-a-time.
  # An example would be creating indices concurrently in PG.
  # @return [Array<String>]
  attr_reader :nontransaction_statements
  # Each of these statements are executed in the application database,
  # NOT whatever database the schema modification itself is executed against.
  # @return [Array<String>]
  attr_reader :application_database_statements

  def initialize
    @transaction_statements = []
    @nontransaction_statements = []
    @application_database_statements = []
  end

  def noop?
    return @transaction_statements.empty? &&
        @nontransaction_statements.empty? &&
        @application_database_statements.empty?
  end

  def execute(db)
    db << stmt2str(@transaction_statements)
    @nontransaction_statements.each { |stmt| db << stmt }
    Webhookdb::Postgres::Model.db << stmt2str(@application_database_statements)
  end

  private def stmt2str(lines)
    return "" if lines.empty?
    return lines.join(";\n") + ";"
  end

  def to_s
    return [stmt2str(@transaction_statements), stmt2str(@nontransaction_statements)].reject(&:blank?).join("\n")
  end
end
