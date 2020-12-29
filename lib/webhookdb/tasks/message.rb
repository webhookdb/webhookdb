# frozen_string_literal: true

require "rake/tasklib"

module Webhookdb::Tasks
  class Message < Rake::TaskLib
    def initialize
      super()
      namespace :message do
        desc "Render the specified message"
        task :render, [:template_class] do |_t, args|
          template_class_name = args[:template_class] or
            raise "Provide the template class name (NewCustomer) as the first argument"

          require "webhookdb"
          Webhookdb.load_app

          delivery = Webhookdb::Message::Delivery.preview(template_class_name, commit: true)
          puts "Created MessageDelivery:"
          pp delivery.values
        end
      end
    end
  end
end
