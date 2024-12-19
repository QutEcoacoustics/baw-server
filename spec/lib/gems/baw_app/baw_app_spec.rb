# frozen_string_literal: true

describe BawApp do
  [
    [
      [:trace, -1, 'trace', 'TRACE'],
      :trace
    ],
    [
      [:debug, 0, 'debug', 'DEBUG', 'Logger::DEBUG'],
      :debug
    ],
    [
      [:info, 1, 'info', 'INFO', 'Logger::INFO'],
      :info
    ],
    [
      [:warn, 2, 'warn', 'WARN', 'Logger::WARN'],
      :warn
    ],
    [
      [:error, 3, 'error', 'ERROR', 'Logger::ERROR'],
      :error
    ],
    [
      [:fatal, 4, 'fatal', 'FATAL', 'Logger::FATAL'],
      :fatal
    ]
  ].each do |variants, expected|
    variants.each do |variant|
      it "can coerce `#{variant}` to `#{expected}`" do
        expect(BawApp.coerce_logger_level(variant)).to eq expected
      end
    end
  end

  it 'has a default log_level of :trace' do
    expect(BawApp.log_level).to eq :trace
  end

  describe 'environment variables', :no_database_cleaning do
    around do  |example|
      existing = {}
      example.metadata[:env].each do |key, value|
        existing[key] = ENV.fetch(key, nil)
        ENV[key] = value
      end

      # reset cache
      Rails.instance_variable_set(:@_env, nil)

      example.call
    ensure
      existing.map do |key, value|
        ENV[key] = value
      end

      # reset cache
      Rails.instance_variable_set(:@_env, nil)
    end

    it 'has can pull a log_level out of RAIL_LOG_LEVEL environment variable', env: {
      'RAILS_LOG_LEVEL' => 'WARN'
    } do
      expect(BawApp.log_level).to eq :warn
    end

    it 'defaults to INFO in staging', env: {
      'RAILS_ENV' => 'staging'
    } do
      expect(BawApp.log_level).to eq :info
    end

    it 'defaults to INFO in staging', env: {
      'RAILS_ENV' => 'production'
    } do
      expect(BawApp.log_level).to eq :info
    end

    it 'prioritizes the RAILS_LOG_LEVEL value', env: {
      'RAILS_ENV' => 'staging',
      'RAILS_LOG_LEVEL' => 'error'
    } do
      expect(BawApp.log_level).to eq :error
    end
  end
end
