# frozen_string_literal: true

RSpec.describe Appydays::Configurable do
  describe "configurable" do
    it "raises if no block is given" do
      expect do
        Class.new do
          include Appydays::Configurable
          configurable(:hello)
        end
      end.to raise_error(LocalJumpError)
    end

    describe "setting" do
      it "creates an attr accessor with the given name and default value" do
        cls = Class.new do
          include Appydays::Configurable
          configurable(:hello) do
            setting :knob, "zero"
          end
        end
        expect(cls).to have_attributes(knob: "zero")
      end

      it "pulls the value from the environment" do
        ENV["ENVTEST_KNOB"] = "one"
        cls = Class.new do
          include Appydays::Configurable
          configurable(:envtest) do
            setting :knob, "zero"
          end
        end
        expect(cls).to have_attributes(knob: "one")
      end

      it "can use a custom environment key" do
        ENV["OTHER_KNOB"] = "two"
        cls = Class.new do
          include Appydays::Configurable
          configurable(:hello) do
            setting :knob, "zero", key: "OTHER_KNOB"
          end
        end
        expect(cls).to have_attributes(knob: "two")
      end

      it "can convert the value given the converter" do
        ENV["CONVTEST_KNOB"] = "0"
        cls = Class.new do
          include Appydays::Configurable
          configurable(:convtest) do
            setting :knob, "", convert: ->(v) { v + v }
          end
        end
        expect(cls).to have_attributes(knob: "00")
      end

      it "does not run the converter if the default is used" do
        cls = Class.new do
          include Appydays::Configurable
          configurable(:hello) do
            setting :knob, "0", convert: ->(v) { v + v }
          end
        end
        expect(cls).to have_attributes(knob: "0")
      end

      it "can use a nil default" do
        cls = Class.new do
          include Appydays::Configurable
          configurable(:hello) do
            setting :knob, nil
          end
        end
        expect(cls).to have_attributes(knob: nil)
      end

      it "converts strings to floats if the default is a float" do
        ENV["FLOATTEST_KNOB"] = "3.2"
        cls = Class.new do
          include Appydays::Configurable
          configurable(:floattest) do
            setting :knob, 1.5
          end
        end
        expect(cls).to have_attributes(knob: 3.2)
      end

      it "converts strings to integers if the default is an integer" do
        ENV["INTTEST_KNOB"] = "5"
        cls = Class.new do
          include Appydays::Configurable
          configurable(:inttest) do
            setting :knob, 2
          end
        end
        expect(cls).to have_attributes(knob: 5)
      end

      it "can coerce strings to booleans" do
        ENV["BOOLTEST_KNOB"] = "TRue"
        cls = Class.new do
          include Appydays::Configurable
          configurable(:booltest) do
            setting :knob, false
          end
        end
        expect(cls).to have_attributes(knob: true)
      end

      it "does not run the converter when using the accessor" do
        cls = Class.new do
          include Appydays::Configurable
          configurable(:booltest) do
            setting :knob, 5
          end
        end
        cls.knob = "5"
        expect(cls).to have_attributes(knob: "5")
      end

      it "coalesces an empty string to nil" do
        cls = Class.new do
          include Appydays::Configurable
          configurable(:hello) do
            setting :knob, ""
          end
        end
        expect(cls).to have_attributes(knob: nil)
      end

      it "errors if the default value is not a supported type" do
        expect do
          Class.new do
            include Appydays::Configurable
            configurable(:hello) do
              setting :knob, []
            end
          end
        end.to raise_error(TypeError)
      end

      it "runs a side effect" do
        side_effect = []
        Class.new do
          include Appydays::Configurable
          configurable(:hello) do
            setting :knob, "zero", side_effect: ->(s) { side_effect << s }
          end
        end
        expect(side_effect).to contain_exactly("zero")
      end
    end

    it "can reset settings" do
      cls = Class.new do
        include Appydays::Configurable
        configurable(:hello) do
          setting :knob, 1
        end
      end
      cls.knob = 5
      expect(cls).to have_attributes(knob: 5)
      cls.reset_configuration
      expect(cls).to have_attributes(knob: 1)
    end

    it "runs after_configure hooks after configuration" do
      side_effect = []
      Class.new do
        include Appydays::Configurable
        configurable(:hello) do
          setting :knob, 1
          after_configured do
            side_effect << self.knob
          end
        end
      end
      expect(side_effect).to contain_exactly(1)
    end

    it "can run after_configured hooks explicitly" do
      side_effect = []
      cls = Class.new do
        include Appydays::Configurable
        configurable(:hello) do
          setting :knob, 1
          after_configured do
            side_effect << self.knob
          end
        end
      end
      cls.run_after_configured_hooks
      expect(side_effect).to contain_exactly(1, 1)
    end
  end
end
