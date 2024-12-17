# frozen_string_literal: true

describe BawApp do
  it 'coerces log level warn' do
    expect(BawApp.log_level('warn')).to eq(Logger::WARN)
  end

  it 'coerces log level info' do
    expect(BawApp.log_level('info')).to eq(Logger::INFO)
  end

  it 'coerces log level debug' do
    expect(BawApp.log_level('debug')).to eq(Logger::DEBUG)
  end

  it 'coerces log level error' do
    expect(BawApp.log_level('error')).to eq(Logger::ERROR)
  end

  it 'coerces log level fatal' do
    expect(BawApp.log_level('fatal')).to eq(Logger::FATAL)
  end

  it 'coerces log level unknown' do
    expect(BawApp.log_level('unknown')).to eq(Logger::UNKNOWN)
  end

  it 'coerces log level nil to default' do
    expect(BawApp.log_level(nil)).to eq(Logger::DEBUG)
  end

  it 'coerces log level without argument to default' do
    expect(BawApp.log_level).to eq(Logger::DEBUG)
  end

  it 'coerces log level WARN' do
    expect(BawApp.log_level('WARN')).to eq(Logger::WARN)
  end

  it 'coerces log level INFO' do
    expect(BawApp.log_level('INFO')).to eq(Logger::INFO)
  end

  it 'coerces log level DEBUG' do
    expect(BawApp.log_level('DEBUG')).to eq(Logger::DEBUG)
  end

  it 'coerces log level ERROR' do
    expect(BawApp.log_level('ERROR')).to eq(Logger::ERROR)
  end

  it 'coerces log level FATAL' do
    expect(BawApp.log_level('FATAL')).to eq(Logger::FATAL)
  end

  it 'coerces log level UNKNOWN' do
    expect(BawApp.log_level('UNKNOWN')).to eq(Logger::UNKNOWN)
  end
end
