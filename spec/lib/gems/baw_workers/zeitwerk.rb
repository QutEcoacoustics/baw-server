# frozen_string_literal: true

describe 'the autoloaders' do
  it 'can load everything' do
    BAW_WORKERS_AUTOLOADER.eager_load(force: true)
  end
end
