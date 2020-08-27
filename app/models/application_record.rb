# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include AlphabeticalPaginatorQuery
  include RendersMarkdown
end
