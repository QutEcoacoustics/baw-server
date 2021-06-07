# frozen_string_literal: true


require 'fixtures/fixtures'

describe 'sqlite filesystems' do
  let(:sqlite_fixture) {
    Fixtures.sqlite_fixture
  }

  before :each do
  end

  it 'ensures we have a valid version of sqlite to use' do
    # we expect this to work if valid, fail if  not valid - this is not a true unit test, more of a test guard
    FileSystems::Sqlite.check_version
  end

  it 'checks the fixture exists' do
    expect(sqlite_fixture.exist?).to be(true)
  end
end
