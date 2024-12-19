# frozen_string_literal: true

describe 'Spec Logger Helpers' do
  include_context 'with a logger spy'

  it 'can log in an example group' do
    example_group = RSpec.describe 'ss' do
      logger.info { 'logger self test' }
    end

    example_group.run

    expect_log_entries_to_include(
      a_hash_including(
        name: a_string_matching(/RSpec/),
        level: 'info',
        message: 'logger self test'
      )
    )
  end

  it 'can log in an example' do
    logger.warn { 'i\'m an example' }

    expect_log_entries_to_include(
      a_hash_including(
        name: a_string_matching(/RSpec/),
        level: 'warn',
        message: 'i\'m an example'
      )
    )
  end
end
