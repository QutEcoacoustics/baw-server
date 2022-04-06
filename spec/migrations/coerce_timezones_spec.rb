# frozen_string_literal: true

require_migration!

# So we're testing a data migration.
# Actually using the tzinfo_tz column in queries now has resulted in invalid timezones in our database
# becoming a major issue.
# We're adding a migration to deal with this, these are the tests.
describe CoerceTimezones, :migration do
  # Format old, expected value after migration
  # These examples were taken directly from a production database
  CASES = [
    ['Asia - Dhaka', 'Asia/Dhaka'],
    ['UTC -2', 'Etc/GMT-2'],
    ['Pacific - Port Moresby', 'Pacific/Port_Moresby'],
    ['Australia - Sydney', 'Australia/Sydney'],
    ['Australia/Adelaide', 'Australia/Adelaide'],
    ['Australia/Brisbane', 'Australia/Brisbane'],
    ['Australia/Sydney', 'Australia/Sydney'],
    ['Australia - Melbourne', 'Australia/Melbourne'],
    ['US - Eastern', 'US/Eastern'],
    [nil, nil],
    ['Australia - NSW', 'Australia/NSW'],
    ['Asia - Singapore', 'Asia/Singapore'],
    ['America - Costa Rica', 'America/Costa_Rica'],
    ['Asia - Yangon', 'Asia/Yangon'],
    ['Asia - Thimphu', 'Asia/Thimphu'],
    ['Australia - Tasmania', 'Australia/Tasmania'],
    ['Australia - Darwin', 'Australia/Darwin'],
    ['Asia - Makassar', 'Asia/Makassar'],
    ['America - Bogota', 'America/Bogota'],
    ['Europe - Berlin', 'Europe/Berlin'],
    ['Australia/Melbourne', 'Australia/Melbourne'],
    ['Australia - Adelaide', 'Australia/Adelaide'],
    ['America - Lima', 'America/Lima'],
    ['Australia - Hobart', 'Australia/Hobart'],
    ['', nil],
    ['Australia - Brisbane', 'Australia/Brisbane'],
    ['Asia - Bangkok', 'Asia/Bangkok']
  ].freeze

  before do
    user_values = ''
    site_values = ''
    CASES.each_with_index do |example, index|
      delimit = index == CASES.length - 1 ? '' : ",\n"
      example => [bad_value, _good_value]
      user_values += "(#{index}, 'user #{index}', 'user#{index}@example.com', 'boogers', '#{bad_value}')#{delimit}"
      site_values += "(#{index}, 'site #{index}', #{index}, '#{bad_value}')#{delimit}"
    end

    # We have corrective code for this problem already in our models
    # we avoid active record and execute raw queries instead
    ActiveRecord::Base.connection.execute(
      <<~SQL
        DELETE FROM datasets;
        DELETE FROM sites;
        DELETE FROM users;

        INSERT INTO users (id, user_name, email, encrypted_password, tzinfo_tz)
        VALUES #{user_values};

        INSERT INTO sites (id, name, creator_id, tzinfo_tz)
        VALUES #{site_values};
      SQL
    )

    expect(User.count).to eq CASES.length
    expect(Site.count).to eq CASES.length
  end

  it 'migrates data correctly for sites' do
    migrate!

    # again execute raw query to avoid corrective code
    results = ActiveRecord::Base.connection.execute(
      <<~SQL
        SELECT id, tzinfo_tz FROM sites ORDER BY id ASC;
      SQL
    )

    # after migration everything should be nice
    aggregate_failures do
      CASES.each_with_index do |example, index|
        example => [bad_value, good_value]

        actual = results[index]['tzinfo_tz']
        expect(actual).to eq(good_value)
      end
    end
  end

  it 'migrates data correctly for users' do
    migrate!

    # again execute raw query to avoid corrective code
    results = ActiveRecord::Base.connection.execute(
      <<~SQL
        SELECT id, tzinfo_tz FROM users ORDER BY id ASC;
      SQL
    )

    # after migration everything should be nice
    aggregate_failures do
      CASES.each_with_index do |example, index|
        example => [bad_value, good_value]

        actual = results[index]['tzinfo_tz']
        expect(actual).to eq(good_value)
      end
    end
  end
end
