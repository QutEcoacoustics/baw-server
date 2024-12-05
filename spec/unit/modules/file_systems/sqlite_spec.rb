# frozen_string_literal: true

require 'fixtures/fixtures'

describe 'sqlite filesystems' do
  it 'ensures we have a valid version of sqlite to use' do
    # we expect this to work if valid, fail if  not valid - this is not a true unit test, more of a test guard
    FileSystems::Containers::Sqlite::Support.check_version
  end
end
