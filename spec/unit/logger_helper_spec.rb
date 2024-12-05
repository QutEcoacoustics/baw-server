# frozen_string_literal: true

describe LoggerHelpers do
  logger.info { 'logger self test' }

  it 'can log in an example group' do
    lines = `grep --text 'logger self test' log/rails.local.test.log`
    expect(lines).to match(/.*I.*RSpec.*logger self test/)
  end

  it 'can log in an example' do
    logger.warn { 'i\'m an example' }
    lines = `tail -n 25 log/rails.local.test.log`

    expect(lines).to match(/.*W.*RSpec.*i'm an example/)
  end
end
