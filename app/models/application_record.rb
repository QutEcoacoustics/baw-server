# frozen_string_literal: true

# Base record for all models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include AlphabeticalPaginatorQuery
  include RendersMarkdown
  include TimestampHelpers
end
