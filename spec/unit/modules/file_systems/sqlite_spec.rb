require 'rails_helper'

describe 'sqlite filesystems' do
  SQLITE_FIXTURE = 'example__Tiles.sqlite3'
  let(:sqlite_fixture) {
    "#{Rails.root}/spec/fixtures/files/#{SQLITE_FIXTURE}"
  }

  before :each do
  end

  it 'ensures we have a valid version of sqlite to use' do
    # we expect this to work if valid, fail if  not valid - this is not a true unit test, more of a test guard
    FileSystems::Sqlite.check_version
  end


end
