# frozen_string_literal: true

require "faker"

module Faker::Webhookdb
  class << self
    def s3_url(opts={})
      opts[:region] ||= ["us-east-2.", ""].sample
      host = "potato.s3.#{opts[:region]}amazonaws.com"
      return self.image_url(host:)
    end

    def image_url(opts={})
      opts[:protocol] ||= ["https", "http"].sample
      opts[:host] ||= ["facebook.com", "flickr.com", "mysite.com"].sample
      opts[:path] ||= "fld"
      opts[:filename] ||= Faker::Lorem.word
      opts[:ext] ||= ["png", "jpg", "jpeg"].sample
      return "#{opts[:protocol]}://#{opts[:host]}/#{opts[:path]}/#{opts[:filename]}.#{opts[:ext]}"
    end

    def us_phone
      s = +"1"
      # First char is never 0 in US area codes
      s << Faker::Number.between(from: 1, to: 9).to_s
      Array.new(9) do
        s << Faker::Number.between(from: 0, to: 9).to_s
      end
      return s
    end
  end
end
