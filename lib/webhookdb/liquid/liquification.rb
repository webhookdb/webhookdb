# frozen_string_literal: true

# Liquification provides a to_liquid method that returns a wrapped object,
# so that any object can be used in a liquid template
# (normally only things like basic types, and objects with to_liquid,
# can be used in templates). This allows us to use Liquid filters for rendering
# custom types, rather than presenters. We prefer filters because
# it keeps display logic in the view, rather than the backing 'template'
# having to choose the presenter.
class Webhookdb::Liquid::Liquification
  def initialize(wrapped)
    @wrapped = wrapped
  end

  def method_missing(m, *args, &)
    return @wrapped.respond_to?(m) ? @wrapped.send(m, *args, &) : super
  end

  def respond_to_missing?(m, include_private: false)
    return super || @wrapped.respond_to?(m)
  end

  def to_liquid
    return self
  end
end
