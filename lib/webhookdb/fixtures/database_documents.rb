# frozen_string_literal: true

require "faker"

require "webhookdb/fixtures"

module Webhookdb::Fixtures::DatabaseDocuments
  extend Webhookdb::Fixtures

  fixtured_class Webhookdb::DatabaseDocument

  base :database_document do
    self.content_type ||= "text/plain"
    self.content ||= Faker::Lorem.paragraph
    self.key ||= Faker::File.file_name(dir: Faker::File.dir)
  end

  decorator :xml do |c="<a><b>hello</b></a>"|
    self.content_type = "application/xml"
    self.content = c
  end

  decorator :html do |c="<html><body><div><strong>hello</strong></div></body></html>"|
    self.content_type = "text/html"
    self.content = c
  end
end
