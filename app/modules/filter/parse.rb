# frozen_string_literal: true

require 'active_support/concern'

module Filter
  # Provides support for parsing a query from a hash.
  module Parse
    extend ActiveSupport::Concern
    extend Validate

    # Parse paging parameters (stand alone).
    # @param [Hash] params
    # @param [Integer] default_page
    # @param [Integer] default_items
    # @param [Integer] max_items
    # @return [Hash] Paging parameters
    def self.parse_paging_only(params, default_page = 1, default_items = 25, max_items = 500)
      instance_method(:parse_paging).bind(self).call(params, default_page, default_items, max_items)
    end

    private

    # Parse paging parameters.
    # @param [Hash] params
    # @param [Integer] default_page
    # @param [Integer] default_items
    # @param [Integer] max_items
    # @return [Hash] Paging parameters
    def parse_paging(params, default_page, default_items, max_items)
      # qsp
      page = params[:page]
      items = params[:items]
      disable_paging = params[:disable_paging]

      # POST body
      page = params[:paging][:page] if page.blank? && params[:paging].present?
      items = params[:paging][:items] if items.blank? && params[:paging].present?
      disable_paging = params[:paging][:disable_paging] if params[:paging].present? && disable_paging.blank?

      # page and items are mutually exclusive with disable_paging
      if (page.present? || items.present?) && disable_paging.present?
        raise CustomErrors::UnprocessableEntityError, 'Page and items are mutually exclusive with disable_paging'
      end

      # set defaults if no setting was found
      page = default_page if page.blank?
      items = default_items if items.blank?

      # ensure integer
      page = page.to_i
      items = items.to_i

      # ensure items is always less than max_items
      if items > max_items
        raise CustomErrors::UnprocessableEntityError,
          "Number of items per page requested #{items} exceeded maximum #{max_items}."
      end

      # parse disable paging settings
      disable_paging = ['true', true].include?(disable_paging)

      # calculate offset and limit
      offset = (page - 1) * items
      limit = items

      # will always set all options
      { offset:, limit:, page:, items:, disable_paging: }
    end

    # Parse sort parameters. Will use defaults if not specified.
    # @param [Hash] params
    # @param [Symbol] default_order_by
    # @param [Symbol] default_direction
    # @return [Hash] Sorting parameters
    def parse_sorting(params, default_order_by, default_direction)
      # qsp
      order_by = params[:order_by]
      direction = params[:direction]

      # POST body
      order_by = params[:sorting][:order_by] if order_by.blank? && params[:sorting].present?
      direction = params[:sorting][:direction] if direction.blank? && params[:sorting].present?

      # set defaults if necessary
      order_by = default_order_by if order_by.blank?
      direction = default_direction if direction.blank?

      # ensure symbols
      order_by = CleanParams.clean(order_by) if order_by.present?
      direction = CleanParams.clean(direction) if direction.present?

      { order_by:, direction: }
    end

    def parse_projection(params)
      return nil unless params.include?(:projection) && params[:projection].present?

      projection = params[:projection]
      projection[:include].map! { |x| CleanParams.clean(x) } if projection in {include: Array}

      projection[:exclude].map! { |x| CleanParams.clean(x) } if projection in {exclude: Array}

      # further validation done is #projections - we're just normalizing values here
      projection
    end

    # Parse text from parameters.
    # Any query string parameter will override filters already present.
    # @param [Hash] params
    # @param [Symbol] key
    # @param [Array<Symbol>] text_fields
    # @return [Hash] filter items
    def parse_qsp_partial_match_text(params, key, text_fields)
      value = params[key].presence

      filter_items = {}

      if value.present?
        text_fields.each do |text_field|
          filter_items[text_field] = { contains: value }
        end
      end

      filter_items
    end

    # Get the QSPs from an object.
    # @param [Object] obj
    # @param [Object] value
    # @param [String] key_prefix
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp(obj, value, key_prefix, found = {})
      case value
      when Hash
        found = parse_qsp_hash(value, key_prefix, found)
      when Array
        found = parse_qsp_array(obj, value, key_prefix, found)
      else
        key_s = obj.blank? ? '' : obj.to_s
        is_filter_qsp = key_s.starts_with?(key_prefix)

        if is_filter_qsp
          key_without_prefix = key_s[key_prefix.size..]
          new_key = CleanParams.clean(key_without_prefix)
          found[new_key] = { eq: value }
        end
      end
      found
    end

    # Get the QSPs from a hash.
    # @param [Hash] hash
    # @param [String] key_prefix
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp_hash(hash, key_prefix, found = {})
      hash.each do |key, value|
        found = parse_qsp(key, value, key_prefix, found)
      end
      found
    end

    # Get the QSPs from an array.
    # @param [Object] key
    # @param [Array] array
    # @param [String] key_prefix
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp_array(key, array, key_prefix, found)
      array.each do |item|
        found = parse_qsp(key, item, key_prefix, found)
      end
      found
    end
  end
end
