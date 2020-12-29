# frozen_string_literal: true

require "appydays/loggable/request_logger"

RSpec.describe Appydays::Loggable do
  it "can set the default log level" do
    expect(SemanticLogger).to receive(:default_level=).with("trace")
    described_class.default_level = "trace"
  end

  it "can look up the logger for an object for a non-Loggable" do
    cls = Class.new
    cls_logger = described_class[cls]
    inst_logger = described_class[cls.new]
    expect(cls_logger).to be_a(SemanticLogger::Logger)
    expect(inst_logger).to be_a(SemanticLogger::Logger)
    expect(cls_logger.name).to eq(inst_logger.name)
  end

  it "can look up the logger for an object for a Loggable" do
    cls = Class.new do
      include Appydays::Loggable
    end
    cls_logger = described_class[cls]
    inst = cls.new
    inst_logger = described_class[inst]
    expect(cls_logger).to be(inst_logger)
    expect(cls.logger).to be(inst.logger)
  end

  it "adds logger methods" do
    cls = Class.new do
      include Appydays::Loggable
    end
    inst = cls.new
    expect(cls.logger).to be_a(SemanticLogger::Logger)
    expect(inst.logger).to be_a(SemanticLogger::Logger)
  end

  describe "custom formatting" do
    it "combines :payload, :tags, and :named_tags into :context" do
      logger1 = described_class["spec-helper-test"]

      lines = capture_logs_from(logger1, formatter: :json) do
        SemanticLogger.tagged("tag1", "tag2") do
          SemanticLogger.named_tagged(nt1: 1, nt2: 2) do
            logger1.error("hello", opt1: 1, opt2: 2)
          end
        end
      end
      j = Yajl::Parser.parse(lines[0])
      expect(j).to include("context")
      expect(j["context"]).to eq(
        "_tags" => ["tag1", "tag2"],
        "nt1" => 1,
        "nt2" => 2,
        "opt1" => 1,
        "opt2" => 2,
      )
    end
  end

  describe "spec helpers" do
    logger1 = described_class["spec-helper-test"]

    it "can capture log lines to a logger" do
      lines = capture_logs_from(logger1) do
        logger1.error("hello there")
      end
      expect(lines).to have_a_line_matching(/hello there/)
    end

    it "can capture log lines to multiple loggers" do
      lines = capture_logs_from(logger1) do
        logger1.error("hello there")
      end
      expect(lines).to have_a_line_matching(/hello there/)
    end

    it "can filter logs below a level" do
      lines = capture_logs_from(logger1, level: :error) do
        logger1.warn("hello there")
      end
      expect(lines).to be_empty
    end

    it "can specify the formatter" do
      lines = capture_logs_from(logger1, formatter: :json) do
        logger1.warn("hello there")
      end
      expect(lines).to have_a_line_matching(/"message":"hello there"/)

      lines = capture_logs_from(logger1, formatter: :color) do
        logger1.warn("hello there")
      end
      expect(lines).to have_a_line_matching(/-- hello there/)
    end

    it "sets and restores the level of all appenders" do
      logger1.level = :info
      other_appender = SemanticLogger.add_appender(io: StringIO.new, level: :trace)
      capture_logs_from(logger1, level: :trace) do
        expect(logger1.level).to eq(:trace)
        expect(other_appender.level).to eq(:fatal)
      end
      expect(logger1.level).to eq(:info)
      expect(other_appender.level).to eq(:trace)
      SemanticLogger.remove_appender(other_appender)
    end
  end

  describe Appydays::Loggable::RequestLogger do
    def run_app(app, opts: {}, loggers: [], env: {}, cls: Appydays::Loggable::RequestLogger)
      rl = cls.new(app, **opts.merge(reraise: false))
      return capture_logs_from(loggers << rl.logger, formatter: :json) do
        _, _, body = rl.call(env)
        body&.close
      end
    end

    it "logs info about the request" do
      lines = run_app(proc { [200, {}, ""] })
      expect(lines).to have_a_line_matching(/"message":"request_finished".*"response_status":200/)

      lines = run_app(proc { [400, {}, ""] })
      expect(lines).to have_a_line_matching(/"message":"request_finished".*"response_status":400/)
    end

    it "logs at 599 (or configured value) if something errors" do
      lines = run_app(proc { raise "testing error" })
      expect(lines).to have_a_line_matching(/"level":"error".*"response_status":599/)
      expect(lines).to have_a_line_matching(/"message":"testing error"/)
    end

    it "logs slow queries at warn" do
      lines = run_app(proc { [200, {}, ""] }, opts: {slow_request_seconds: 0})
      expect(lines).to have_a_line_matching(/"level":"warn".*"response_status":200/)
    end

    it "logs errors at error" do
      lines = run_app(proc { [504, {}, ""] }, opts: {slow_request_seconds: 0})
      expect(lines).to have_a_line_matching(/"level":"error".*"response_status":504/)
    end

    it "adds tags around the execution of the request" do
      logger = SemanticLogger["testlogger"]
      lines = run_app(proc do
                        logger.info("check for tags")
                        [200, {}, ""]
                      end,
                      opts: {slow_request_seconds: 0}, loggers: [logger],)
      expect(lines).to have_a_line_matching(/"message":"check for tags".*"request_method":/)
    end

    it "adds subclass tags" do
      ReqLogger = Class.new(Appydays::Loggable::RequestLogger) do
        def request_tags(env)
          return {my_header_tag: env["HTTP_MY_HEADER"]}
        end
      end
      lines = run_app(proc { [200, {}, ""] }, env: {"HTTP_MY_HEADER" => "myval"}, cls: ReqLogger)
      expect(lines).to have_a_line_matching(/"my_header_tag":"myval"/)
    end

    it "adds a request id" do
      lines = run_app(proc { [200, {}, ""] })
      expect(lines).to have_a_line_matching(/"request_id":"[0-9a-z]{8}-/)
    end

    it "reads a trace id from headers" do
      lines = run_app(proc { [200, {}, ""] }, env: {"HTTP_TRACE_ID" => "123xyz"})
      expect(lines).to have_a_line_matching(/"trace_id":"123xyz"/)
    end

    it "sets the trace ID header if not set" do
      env = {}
      lines = run_app(proc do
        expect(env).to(include("HTTP_TRACE_ID"))
        [200, {}, ""]
      end, env: env,)
      expect(lines).to have_a_line_matching(/"trace_id":"[0-9a-z]{8}-/)
    end
  end
end
