# frozen_string_literal: true

module AlphabeticalPaginatorHelper
  # make our custom url generation methods available to views
  include Api::CustomUrlHelpers

  def alphabetical_paginator(current_page = 'a', window_size = 1, index_size = 1)
    raise if window_size < 1
    raise if index_size < 1

    other = AlphabeticalPaginatorQuery::OTHER #"\u{1F30F}"
    numbers = AlphabeticalPaginatorQuery::NUMBERS
    start_char = 'a'
    end_char = 'z'

    pages = [
      make_page(other, other, current_page),
      make_page(numbers, numbers, current_page)
    ]

    current = 0
    min = 0
    max = ((end_char.ord + 1 - start_char.ord)**index_size) - 1
    while current <= max
      next_number = current + window_size

      left = get_chars(current, 26, index_size, start_char.ord)
      right = get_chars([max, next_number - 1].min, 26, index_size, start_char.ord)

      page = left + '-' + right
      title = left
      title = page if window_size != 1 || index_size != 1

      pages << make_page(title, page, current_page)

      current = next_number
    end

    render partial: 'shared/alphabetical_paginator', locals: {
      paginator: {
        pages: pages
      }
    }
  end

  private

  def get_chars(index, delta, index_size, offset)
    result = ''
    (1..index_size).each do |i|
      char = (index / (delta**(index_size - i))) % delta
      result += (offset + char).to_i.chr
    end

    result
  end

  def make_page(title, page, current_page)
    {
      title: title,
      page: page,
      current?: page == current_page
    }
  end
end
