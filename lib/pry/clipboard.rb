# frozen_string_literal: true

require "pry"
require "clipboard"

# Originally from https://github.com/hotchpotch/pry-clipboard
# but modified since it is broken in Ruby 2.7
module Pry::Clipboard
  Command = Pry::CommandSet.new do
    create_command "paste" do
      description "Paste from clipboard"

      banner <<-BANNER
        Usage: paste [-q|--quiet]
      BANNER

      def options(opt)
        opt.on :q, :quiet, "quiet output", optional: true
      end

      def process
        str = Clipboard.paste
        unless opts.present?(:q)
          pry_instance.output.puts green("-*-*- Paste from clipboard -*-*-")
          pry_instance.output.puts str
        end
        eval_string << str
      end
    end

    create_command "copy-history" do
      description "Copy history to clipboard"

      banner <<-BANNER
          Usage: copy-history [N] [-T|--tail N] [-H|--head N] [-R|--range N..M]  [-G|--grep match] [-l] [-q|--quiet]
          e.g: `copy-history`
          e.g: `copy-history -l`
          e.g: `copy-history 10`
          e.g: `copy-history -H 10`
          e.g: `copy-history -T 5`
          e.g: `copy-history -R 5..10`
      BANNER

      def options(opt)
        opt.on :l, "Copy history with last result", optional: true
        opt.on :H, :head, "Copy the first N items.", optional: true, as: Integer
        opt.on :T, :tail, "Copy the last N items.", optional: true, as: Integer
        opt.on :R, :range, "Copy the given range of lines.", optional: true, as: Range
        opt.on :G, :grep, "Copy lines matching the given pattern.", optional: true, as: String
        opt.on :q, :quiet, "quiet output", optional: true
      end

      def process
        history = Pry::Code(Pry.history.to_a)

        history = if num_arg
                    history.take_lines(num_arg, 1)
        else
          history = history.grep(opts[:grep]) if opts.present?(:grep)
          if opts.present?(:range)
            history.between(opts[:range])
          elsif opts.present?(:head)
            history.take_lines(1, opts[:head] || 10)
          elsif opts.present?(:tail) || opts.present?(:grep)
            n = opts[:tail] || 10
            n = history.lines.count if n > history.lines.count
            history.take_lines(-n, n)
          else
            history.take_lines(-1, 1)
          end
        end

        str = history.raw
        str += "#=> #{pry_instance.last_result}\n" if opts.present?(:l)
        Clipboard.copy str

        return if opts.present?(:q)
        pry_instance.output.puts green("-*-*- Copy history to clipboard -*-*-")
        pry_instance.output.puts str
      end

      def num_arg
        first = args[0]
        first.to_i if first && first.to_i.to_s == first
      end
    end

    create_command "copy-result" do
      description "Copy result to clipboard."

      banner <<-BANNER
          Usage: copy-result [-q|--quiet]
      BANNER

      def options(opt)
        opt.on :q, :quiet, "quiet output", optional: true
      end

      def process
        res = "#{pry_instance.last_result}\n"
        Clipboard.copy res

        return if opts.present?(:q)
        pry_instance.output.puts green("-*-*- Copy result to clipboard -*-*-")
        pry_instance.output.print res
      end
    end
  end
end

Pry.commands.import Pry::Clipboard::Command
