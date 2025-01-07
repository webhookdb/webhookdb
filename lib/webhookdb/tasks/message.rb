# frozen_string_literal: true

require "rake/tasklib"

module Webhookdb::Tasks
  class Message < Rake::TaskLib
    def initialize
      super
      namespace :message do
        desc "Render the specified message"
        task :render, [:template_class, :out] do |_t, args|
          template_class_name = args[:template_class] or
            raise "Provide the template class name (NewCustomer or new_customer) as the first argument"
          outpath = args[:out]
          outpath = nil if outpath.blank? || outpath == "-"
          if outpath
            html_io = File.open(outpath, "w")
            feedback_io = $stdout
          else
            html_io = $stdout
            feedback_io = $stderr
          end

          ENV["WEBHOOKDB_DB_SLOW_QUERY_SECONDS"] ||= "1"
          require "webhookdb"
          Webhookdb.load_app
          SemanticLogger.appenders.to_a.each { |a| SemanticLogger.remove_appender(a) }
          SemanticLogger.add_appender(io: feedback_io)

          commit = Webhookdb::RACK_ENV != "test"
          clsname = template_class_name.classify
          (clsname += "s") if template_class_name.end_with?("s") && !clsname.end_with?("s")
          delivery = Webhookdb::Message::Delivery.preview(clsname, commit:)
          feedback_io << "*** Created MessageDelivery: #{delivery.values}\n\n"
          feedback_io << delivery.body_with_mediatype!("text/plain")&.content
          feedback_io << "\n\n"
          if outpath
            feedback_io << "*** Writing HTML output to #{outpath}\n"
          elsif html_io.tty?
            feedback_io << "*** Writing HTML output to stdout.\n"
            feedback_io << "*** Redirect it to a file (> temp.html), pass OUT to write it to a file (OUT=temp.html),\n"
            feedback_io << "*** or view it at /admin_api/v1/message_deliveries/last\n\n"
          else
            feedback_io << "*** Writing HTML output to redirected stdout.\n"
          end
          html_io << delivery.body_with_mediatype!("text/html")&.content
          html_io << "\n"
        end
      end
    end
  end
end
