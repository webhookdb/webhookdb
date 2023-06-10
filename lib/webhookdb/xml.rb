# frozen_string_literal: true

class Webhookdb::Xml
  module Atom
    def self.parse(thing)
      Parser.new(thing).to_hash
    end

    def self.parse_entry(thing)
      p = Parser.new(thing)
      p.parse_entry(p.doc.root)
    end

    class Parser
      attr_reader :doc

      def initialize(thing)
        @doc = Nokogiri::XML.parse(thing, &:noblanks)
      end

      def to_hash
        entries = []
        feed = {"entries" => entries}
        @doc.root.children.each do |c|
          if c.is_a?(Nokogiri::XML::Text)
            next
          elsif c.name == "entry"
            entries << self.parse_entry(c)
          elsif self.spec_attr?(c)
            feed[self.fqn(c)] = self.parse_spec_attr(c)
          elsif self.simple_text?(c)
            feed[self.fqn(c)] = self.text(c)
          else
            feed[self.fqn(c)] = self.parse_to_hash(c)
          end
        end
        return feed
      end

      protected def simple_text?(c) = c.children.size == 1 && c.children[0].is_a?(Nokogiri::XML::Text)
      protected def spec_attr?(c) = ["link", "category"].include?(c.name)

      protected def parse_spec_attr(c)
        h = {}
        c.attributes.each do |k, v|
          h[k] = v.value
        end
        h["text"] = self.text(c) if simple_text?(c)
        return h
      end

      def parse_entry(e)
        h = {}
        e.children.each do |c|
          if c.name == "content"
            content = {}
            h["content"] = content
            content["value"] = c.children.to_s if c.children.to_s.present?
            c.attributes.each do |k, v|
              content[k] = v.value
            end
          elsif self.spec_attr?(c)
            h[self.fqn(c)] = self.parse_spec_attr(c)
          else
            h[self.fqn(c)] = c.text
          end
        end
        return h
      end

      protected def fqn(c)
        return c.name unless c.namespace&.prefix
        return "#{c.namespace.prefix}:#{c.name}"
      end

      protected def parse_to_hash(c)
        h = {}
        c.children.each do |cc|
          h[self.fqn(cc)] = self.text(cc)
        end
        return h
      end

      protected def text(c)
        t = c.children.first
        return "" if t.nil?
        raise ArgumentError, "child is not text: #{c}" unless t.is_a?(Nokogiri::XML::Text)
        return t.text
      end
    end
  end
end
