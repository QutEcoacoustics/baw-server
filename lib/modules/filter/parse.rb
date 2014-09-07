require 'active_support/concern'

module Filter

  # Provides support for parsing a query from a hash.
  module Parse
    extend ActiveSupport::Concern
    extend Validate

    private

    # Parse paging parameters.
    # @param [Hash] params
    # @param [Integer] default_items
    # @return [Hash] Paging parameters
    def parse_paging(params, default_items)
      page, items, offset, limit = nil

      # qsp
      page = params[:page]
      items = params[:items]

      # POST body
      page = params[:paging][:page] if page.blank? && !params[:paging].blank?
      items = params[:paging][:items] if items.blank? && !params[:paging].blank?

      # if page or items is set, set the other to default
      page = 1 if page.blank? && !items.blank?
      items = default_items if !page.blank? && items.blank?

      # calculate offset if able
      offset = (page - 1) * items if !page.blank? && !items.blank?
      limit = items if !page.blank? && !items.blank?
      #page = (values.offset / values.limit) + 1

      # ensure integer
      offset = offset.to_i unless offset.blank?
      limit = limit.to_i unless limit.blank?
      page = page.to_i unless page.blank?
      items = items.to_i unless items.blank?

      # will always return offset, limit, page, items
      # either all will be nil, or all will be set
      {offset: offset, limit: limit, page: page, items: items}
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
      order_by = params[:sorting][:order_by] if order_by.blank? && !params[:sorting].blank?
      direction = params[:sorting][:direction] if order_by.blank? && !params[:sorting].blank?

      # set defaults if necessary
      order_by = default_order_by if order_by.blank?
      direction = default_direction if direction.blank?

      # ensure symbols
      order_by = CleanParams.clean(order_by) unless order_by.blank?
      direction = CleanParams.clean(direction) unless direction.blank?

      {order_by: order_by, direction: direction}
    end

    # Parse text from parameters.
    # @param [Hash] params
    # @param [Symbol] key
    # @return [String] condition
    def parse_qsp_text(params, key = :filter_partial_match)
      params[key].blank? ? nil : params[key]
    end

    # Get the QSPs from an object.
    # @param [Object] obj
    # @param [Object] value
    # @param [String] key_prefix
    # @param [Array<Symbol>] valid_fields
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp(obj, value, key_prefix, valid_fields, found = {})
      if value.is_a?(Hash)
        found = parse_qsp_hash(value, key_prefix, valid_fields, found)
      elsif value.is_a?(Array)
        found = parse_qsp_array(obj, value, key_prefix, valid_fields, found)
      else
        key_s = obj.blank? ? '' : obj.to_s
        is_filter_qsp = key_s.starts_with?(key_prefix)

        if is_filter_qsp
          new_key = CleanParams.clean(key_s[key_prefix.size..-1])
          found[new_key] = value if valid_fields.include?(new_key)
        end
      end
      found
    end

    # Get the QSPs from a hash.
    # @param [Hash] hash
    # @param [String] key_prefix
    # @param [Array<Symbol>] valid_fields
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp_hash(hash, key_prefix, valid_fields, found = {})
      hash.each do |key, value|
        found = parse_qsp(key, value, key_prefix, valid_fields, found)
      end
      found
    end

    # Get the QSPs from an array.
    # @param [Object] key
    # @param [Array] array
    # @param [String] key_prefix
    # @param [Array<Symbol>] valid_fields
    # @param [Hash] found
    # @return [Hash] matching entries
    def parse_qsp_array(key, array, key_prefix, valid_fields, found)
      array.each do |item|
        found = parse_qsp(key, item, key_prefix, valid_fields, found)
      end
      found
    end

  end
end