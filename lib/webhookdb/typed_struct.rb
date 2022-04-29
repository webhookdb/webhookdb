# frozen_string_literal: true

class Webhookdb::TypedStruct
  def initialize(**kwargs)
    self._defaults.merge(kwargs).each do |k, v|
      raise TypeError, "invalid struct field #{k}" unless self.respond_to?(k)
      self.instance_variable_set("@#{k}".to_sym, v)
    end
  end

  def _defaults
    return {}
  end

  def [](k)
    return self.send(k)
  end
end
