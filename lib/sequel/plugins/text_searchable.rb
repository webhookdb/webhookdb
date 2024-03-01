# frozen_string_literal: true

require "sequel/text_searchable"

module Sequel::Plugins::TextSearchable
  DEFAULT_OPTIONS = {
    column: :text_search,
    search_options: {
      to_tsquery: :websearch,
      language: "english",
      rank: true,
    },
    terms: nil,
  }.freeze

  def self.configure(model, opts=DEFAULT_OPTIONS)
    opts = DEFAULT_OPTIONS.merge(opts)
    model.text_search_column = opts[:column]
    model.text_search_options = opts[:search_options]
    model.text_search_terms = opts[:terms]
    SequelTextSearchable.searchable_models << model
  end

  module DatasetMethods
    def text_search(q, opts={})
      full_opts = self.model.text_search_options.merge(tsvector: true).merge(opts)
      return self.full_text_search(self.model.text_search_column, q, **full_opts)
    end
  end

  module ClassMethods
    attr_accessor :text_search_column, :text_search_options, :text_search_terms

    def text_search_language = self.text_search_options.fetch(:language)

    def text_search_reindex_all
      did = 0
      self.dataset.paged_each do |m|
        m.text_search_reindex
        did += 1
      end
      return did
    end

    def text_search_reindex_model(model_pk)
      m = self.with_pk!(model_pk)
      m.text_search_reindex
      return m
    end
  end

  module InstanceMethods
    def after_save
      super
      if SequelTextSearchable.index_mode == :async
        # We must refetch the model to index since it happens on another thread.
        SequelTextSearchable.threadpool.post do
          self.model.text_search_reindex_model(self.pk)
        end

      elsif SequelTextSearchable.index_mode == :sync
        self.text_search_reindex
      end
    end

    # Return the values used for the tsvector value.
    #
    # In general this should include relevant text fields (like name and descriptions)
    # on the receiver and related objects.
    #
    # Each value in the array can be one of the following:
    #
    # - nil: skipped
    # - str like 'value': Used in `to_tsvector('value')`.
    # - tuple[str, str] like ('value, 'B'): Used in `setweight(to_tsvector('value'), 'B')
    # - has a text_search_values_for_related' method: All of these are included in the returned list.
    #     Useful for adding all of a parent relation's fields to related components,
    #     while the parent may need a more complex text_search_values.
    # - has a 'text_search_values' method: All of these are included in the returned list.
    def text_search_terms
      raise NotImplementedError, "#{self.class.name} must implement text_search_terms" if
        self.model.text_search_terms.nil?
      return self.model.text_search_terms.map do |t|
        if t.is_a?(Array)
          col, rank = t
        elsif t.is_a?(Hash)
          col, rank = t.to_a.first
        else
          col = t
          rank = nil
        end
        val = self.send(col)
        rank ? [val, rank] : val
      end
    end

    def text_search_reindex
      got_terms = self.text_search_terms
      return if got_terms.empty?
      terms = got_terms.flat_map { |t| _text_search_term_to_col_and_rank(t) }
      exprs = terms.filter_map do |(col, rank)|
        col = Sequel.function(:coalesce, col, "")
        expr = Sequel.function(:to_tsvector, self.model.text_search_language, col)
        expr = Sequel.function(:setweight, expr, rank) if rank
        expr
      end
      full_expr = Sequel.join(exprs)
      self.this.update(self.model.text_search_column => full_expr)
    end

    private def _text_search_term_to_col_and_rank(t, norank: false)
      return nil if t.nil?
      if t.is_a?(Array)
        c, r = t
        r = nil if norank
        return [[c, r]]
      end
      if t.is_a?(Hash)
        c, r = t.to_a.first
        r = nil if norank
        return [[c, r]]
      end
      related_cols_ranks = if t.respond_to?(:text_search_terms_for_related)
                             t.text_search_terms_for_related
      elsif t.respond_to?(:text_search_terms)
        t.text_search_terms
      else
        return [[t, nil]]
      end
      return related_cols_ranks.flat_map do |relterm|
        _text_search_term_to_col_and_rank(relterm, norank: true)
      end
    end
  end
end
