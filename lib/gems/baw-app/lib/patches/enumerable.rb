# frozen_string_literal: true

module BawApp
  # Patches for the Enumerable class.
  module Enumerable
    def format_inline_list(delimiter: ', ', quote: '`')
      map { |v| "#{quote}#{v}#{quote}" }.join(delimiter)
    end
  end
end

Enumerable.include BawApp::Enumerable
