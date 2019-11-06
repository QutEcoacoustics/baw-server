# frozen_string_literal: true

require 'pathname'

module Fixtures
  FIXTURES_PATH = Pathname.new("#{::Rails.root}/spec/fixtures")
  FILES_PATH = FIXTURES_PATH / 'files'

  # @return [Pathname]
  def self.sqlite_fixture
    FILES_PATH / 'example__Tiles.sqlite3'
  end
end
