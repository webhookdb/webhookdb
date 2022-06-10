# frozen_string_literal: true

class Webhookdb::TypedStruct
  def initialize(**kwargs)
    self._apply(self._defaults.merge(kwargs))
  end

  def _defaults
    return {}
  end

  def [](k)
    return self.send(k)
  end

  # Modify the receiver with kwargs.
  def _apply(kwargs)
    kwargs.each do |k, v|
      raise TypeError, "invalid struct field #{k}" unless self.respond_to?(k)
      self.instance_variable_set("@#{k}".to_sym, v)
    end
  end

  def change(**kwargs)
    c = self.dup
    c._apply(**kwargs)
    return c
  end

  protected def typecheck!(field, type, nullable: false)
    value = self.send(field)
    return if nullable && value.nil?
    if type == :boolean
      return if [true, false].include?(value)
    elsif value.is_a?(type)
      return
    end
    raise ArgumentError, "#{field} #{value.inspect} must be a #{type.name}"
  end
end
