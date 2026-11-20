# frozen_string_literal: true

require "webhookdb/message/template"

module Webhookdb::Messages::Testers
  class Base < Webhookdb::Message::Template
    def template_folder
      return "specs"
    end

    def layout
      return nil
    end
  end

  class Basic < Base
  end

  class WithField < Base
    def initialize(field)
      @field = field
      super()
    end

    def liquid_drops
      return super.merge(field: @field)
    end
  end

  class WithFields < Base
    # noinspection RubyInstanceVariableNamingConvention
    def initialize(a: nil, b: nil, c: nil, d: nil, e: nil)
      @a = a
      @b = b
      @c = c
      @d = d
      @e = e
      super()
    end

    def liquid_drops
      return super.merge(a: @a, b: @b, c: @c, d: @d, e: @e)
    end
  end

  class Nonextant < Base
  end

  class MissingField < Base
    def template_name
      return "with_field"
    end
  end

  class WithInclude < Base
    def liquid_drops
      return super.merge(field: 3)
    end
  end

  class WithPartial < Base
  end

  class WithLayout < Base
    def template_name
      return "basic"
    end

    def layout
      return "standard"
    end
  end
end
