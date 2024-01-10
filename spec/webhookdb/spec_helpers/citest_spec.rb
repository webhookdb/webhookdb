# frozen_string_literal: true

require "webhookdb/spec_helpers/citest"

RSpec.describe Webhookdb::SpecHelpers::Citest, :db do
  describe "run_tests", reset_configuration: Webhookdb::Slack do
    before(:each) do
      @slack_http = Webhookdb::Slack::NoOpHttpClient.new
      Webhookdb::Slack.http_client = @slack_http
      Webhookdb::Slack.suppress_all = false
    end

    after(:each) do
      Webhookdb::Slack.http_client = nil
    end

    it "runs tests with RSpec" do
      expect(RSpec::Core::Runner).to receive(:run).with(["testdir/", "--format", "html"], be_a(StringIO),
                                                        be_a(StringIO),) do |_, _, out|
        out << '<script type="text/javascript">document.getElementById("totals").innerHTML = ' \
               '"4 examples, 1 failure, 2 pending";</script>'
      end
      described_class.run_tests("testdir")
      expect(@slack_http.posts).to contain_exactly(
        [be_a(URI), include(payload: include("4 examples, 1 failures"))],
      )
    end

    it "posts an error if no results are parsed" do
      expect(RSpec::Core::Runner).to receive(:run).with(["testdir/", "--format", "html"], be_a(StringIO),
                                                        be_a(StringIO),)
      described_class.run_tests("testdir")
      expect(@slack_http.posts).to contain_exactly(
        [be_a(URI), include(payload: include("Errored or unparseable output running testdir tests"))],
      )
    end
  end

  describe "parse_rspec_output" do
    it "can parse HTML RSpec output" do
      s = <<~HEREDOC
        Run options: include {:focus=>true}
        <!DOCTYPE html>
        <html lang='en'>
        <head>
          <title>RSpec results</title>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
          <meta http-equiv="Expires" content="-1" />
          <meta http-equiv="Pragma" content="no-cache" />
          <style type="text/css">
          body {
            margin: 0;
            padding: 0;
            background: #fff;
            font-size: 80%;
          }
          </style>
          <script type="text/javascript">
            // <![CDATA[

        function addClass(element_id, classname) {
          document.getElementById(element_id).className += (" " + classname);
        }

        function removeClass(element_id, classname) {
          var elem = document.getElementById(element_id);
          var classlist = elem.className.replace(classname,'');
          elem.className = classlist;
        }

        function moveProgressBar(percentDone) {
          document.getElementById("rspec-header").style.width = percentDone +"%";
        }

        function makeRed(element_id) {
          removeClass(element_id, 'passed');
          removeClass(element_id, 'not_implemented');
          addClass(element_id,'failed');
        }

        function makeYellow(element_id) {
          var elem = document.getElementById(element_id);
          if (elem.className.indexOf("failed") == -1) {  // class doesn't includes failed
            if (elem.className.indexOf("not_implemented") == -1) { // class doesn't include not_implemented
              removeClass(element_id, 'passed');
              addClass(element_id,'not_implemented');
            }
          }
        }

        function apply_filters() {
          var passed_filter = document.getElementById('passed_checkbox').checked;
          var failed_filter = document.getElementById('failed_checkbox').checked;
          var pending_filter = document.getElementById('pending_checkbox').checked;

          assign_display_style("example passed", passed_filter);
          assign_display_style("example failed", failed_filter);
          assign_display_style("example not_implemented", pending_filter);

          assign_display_style_for_group("example_group passed", passed_filter);
          assign_display_style_for_group("example_group not_implemented", pending_filter, pending_filter || passed_filter);
          assign_display_style_for_group("example_group failed", failed_filter, failed_filter || pending_filter || passed_filter);
        }

        function get_display_style(display_flag) {
          var style_mode = 'none';
          if (display_flag == true) {
            style_mode = 'block';
          }
          return style_mode;
        }

        function assign_display_style(classname, display_flag) {
          var style_mode = get_display_style(display_flag);
          var elems = document.getElementsByClassName(classname)
          for (var i=0; i<elems.length;i++) {
            elems[i].style.display = style_mode;
          }
        }

        function assign_display_style_for_group(classname, display_flag, subgroup_flag) {
          var display_style_mode = get_display_style(display_flag);
          var subgroup_style_mode = get_display_style(subgroup_flag);
          var elems = document.getElementsByClassName(classname)
          for (var i=0; i<elems.length;i++) {
            var style_mode = display_style_mode;
            if ((display_flag != subgroup_flag) && (elems[i].getElementsByTagName('dt')[0].innerHTML.indexOf(", ") != -1)) {
              elems[i].style.display = subgroup_style_mode;
            } else {
              elems[i].style.display = display_style_mode;
            }
          }
        }

            // ]]>
          </script>
          <style type="text/css">
        #rspec-header {
          background: #65C400; color: #fff; height: 4em;
        }

        .rspec-report h1 {
          margin: 0px 10px 0px 10px;
          padding: 10px;
          font-family: "Lucida Grande", Helvetica, sans-serif;
          font-size: 1.8em;
          position: absolute;
        }

        #label {
          float:left;
        }

        #display-filters {
          float:left;
          padding: 28px 0 0 40%;
          font-family: "Lucida Grande", Helvetica, sans-serif;
        }

        #summary {
          float:right;
          padding: 5px 10px;
          font-family: "Lucida Grande", Helvetica, sans-serif;
          text-align: right;
        }

        #summary p {
          margin: 0 0 0 2px;
        }

        #summary #totals {
          font-size: 1.2em;
        }

        .example_group {
          margin: 0 10px 5px;
          background: #fff;
        }

        dl {
          margin: 0; padding: 0 0 5px;
          font: normal 11px "Lucida Grande", Helvetica, sans-serif;
        }

        dt {
          padding: 3px;
          background: #65C400;
          color: #fff;
          font-weight: bold;
        }

        dd {
          margin: 5px 0 5px 5px;
          padding: 3px 3px 3px 18px;
        }

        dd .duration {
          padding-left: 5px;
          text-align: right;
          right: 0px;
          float:right;
        }

        dd.example.passed {
          border-left: 5px solid #65C400;
          border-bottom: 1px solid #65C400;
          background: #DBFFB4; color: #3D7700;
        }

        dd.example.not_implemented {
          border-left: 5px solid #FAF834;
          border-bottom: 1px solid #FAF834;
          background: #FCFB98; color: #131313;
        }

        dd.example.pending_fixed {
          border-left: 5px solid #0000C2;
          border-bottom: 1px solid #0000C2;
          color: #0000C2; background: #D3FBFF;
        }

        dd.example.failed {
          border-left: 5px solid #C20000;
          border-bottom: 1px solid #C20000;
          color: #C20000; background: #FFFBD3;
        }


        dt.not_implemented {
          color: #000000; background: #FAF834;
        }

        dt.pending_fixed {
          color: #FFFFFF; background: #C40D0D;
        }

        dt.failed {
          color: #FFFFFF; background: #C40D0D;
        }


        #rspec-header.not_implemented {
          color: #000000; background: #FAF834;
        }

        #rspec-header.pending_fixed {
          color: #FFFFFF; background: #C40D0D;
        }

        #rspec-header.failed {
          color: #FFFFFF; background: #C40D0D;
        }


        .backtrace {
          color: #000;
          font-size: 12px;
        }

        a {
          color: #BE5C00;
        }

        /* Ruby code, style similar to vibrant ink */
        .ruby {
          font-size: 12px;
          font-family: monospace;
          color: white;
          background-color: black;
          padding: 0.1em 0 0.2em 0;
        }

        .ruby .keyword { color: #FF6600; }
        .ruby .constant { color: #339999; }
        .ruby .attribute { color: white; }
        .ruby .global { color: white; }
        .ruby .module { color: white; }
        .ruby .class { color: white; }
        .ruby .string { color: #66FF00; }
        .ruby .ident { color: white; }
        .ruby .method { color: #FFCC00; }
        .ruby .number { color: white; }
        .ruby .char { color: white; }
        .ruby .comment { color: #9933CC; }
        .ruby .symbol { color: white; }
        .ruby .regex { color: #44B4CC; }
        .ruby .punct { color: white; }
        .ruby .escape { color: white; }
        .ruby .interp { color: white; }
        .ruby .expr { color: white; }

        .ruby .offending { background-color: gray; }
        .ruby .linenum {
          width: 75px;
          padding: 0.1em 1em 0.2em 0;
          color: #000000;
          background-color: #FFFBD3;
        }

          </style>
        </head>
        <body>
        <div class="rspec-report">

        <div id="rspec-header">
          <div id="label">
            <h1>RSpec Code Examples</h1>
          </div>

          <div id="display-filters">
            <input id="passed_checkbox"  name="passed_checkbox"  type="checkbox" checked="checked" onchange="apply_filters()" value="1" /> <label for="passed_checkbox">Passed</label>
            <input id="failed_checkbox"  name="failed_checkbox"  type="checkbox" checked="checked" onchange="apply_filters()" value="2" /> <label for="failed_checkbox">Failed</label>
            <input id="pending_checkbox" name="pending_checkbox" type="checkbox" checked="checked" onchange="apply_filters()" value="3" /> <label for="pending_checkbox">Pending</label>
          </div>

          <div id="summary">
            <p id="totals">&#160;</p>
            <p id="duration">&#160;</p>
          </div>
        </div>


        <div class="results">
        <div id="div_group_1" class="example_group passed">
          <dl style="margin-left: 0px;">
          <dt id="example_group_1" class="passed">Webhookdb::SpecHelpers::Citest</dt>
          </dl>
        </div>
        <div id="div_group_2" class="example_group passed">
          <dl style="margin-left: 15px;">
          <dt id="example_group_2" class="passed">parse_rspec_output</dt>
            <script type="text/javascript">moveProgressBar('50.0');</script>
            <dd class="example passed"><span class="passed_spec_name">can parse failure output</span><span class='duration'>0.00036s</span></dd>
            <script type="text/javascript">moveProgressBar('100.0');</script>
            <dd class="example passed"><span class="passed_spec_name">can parse success output</span><span class='duration'>0.00013s</span></dd>
          </dl>
        </div>
        <script type="text/javascript">document.getElementById('duration').innerHTML = "Finished in <strong>0.67432 seconds</strong>";</script>
        <script type="text/javascript">document.getElementById('totals').innerHTML = "4 examples, 1 failure, 2 pending";</script>
        </div>
        </div>
        </body>
        </html>
      HEREDOC
      res = described_class.parse_rspec_html(s)
      expect(res.examples).to eq(4)
      expect(res.failures).to eq(1)
      expect(res.pending).to eq(2)
      expect(res.html).to start_with("<!DOCTYPE html>")
      expect(res.html.strip).to end_with("</html>")
    end

    it "defaults pending to 0 if not present" do
      s = <<~HEREDOC
        <script type="text/javascript">document.getElementById('totals').innerHTML = "4 examples, 1 failure";</script>
      HEREDOC
      res = described_class.parse_rspec_html(s)
      expect(res.examples).to eq(4)
      expect(res.failures).to eq(1)
      expect(res.pending).to eq(0)
    end
  end

  describe "result_to_payload" do
    let(:result) do
      res = described_class::RSpecResult.new
      res.examples = 5
      res.failures = 0
      res.pending = 0
      res
    end

    it "converts results and an upload URL to a Slack payload" do
      expect(described_class.result_to_payload(result, "http://results.html")).to eq(
        attachments: [
          {
            color: "good",
            actions: [{text: "View Results 🔎", type: "button", url: "http://results.html"}],
            fallback: "View results at http://results.html",
          },
        ],
        text: "Integration Tests: 5 examples, 0 failures, 0 pending",
      )
    end

    it "uses danger color if there are any failures" do
      result.pending = 1
      result.failures = 2
      expect(described_class.result_to_payload(result, "http://results.html")).to eq(
        attachments: [
          {
            color: "danger",
            actions: [{text: "View Results 🔎", type: "button", url: "http://results.html"}],
            fallback: "View results at http://results.html",
          },
        ],
        text: "Integration Tests: 5 examples, 2 failures, 1 pending",
      )
    end

    it "uses warning color if there are any pending" do
      result.pending = 1
      expect(described_class.result_to_payload(result, "http://results.html")).to eq(
        attachments: [
          {
            color: "warning",
            actions: [{text: "View Results 🔎", type: "button", url: "http://results.html"}],
            fallback: "View results at http://results.html",
          },
        ],
        text: "Integration Tests: 5 examples, 0 failures, 1 pending",
      )
    end
  end

  describe "put_results" do
    it "saves the results and returns a signed url" do
      expect(described_class.put_results("<html />")).to match(
        %r{http://localhost:18001/admin/v1/database_documents/\d+/view\?expire_at=\d+&sig=.*},
      )
    end
  end
end
