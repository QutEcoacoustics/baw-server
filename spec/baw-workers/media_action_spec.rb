require 'spec_helper'

describe BawWorkers::MediaAction do
  include_context 'common'

  context 'should execute perform method' do
    it 'for spectrogram' do
      expect {
        BawWorkers::MediaAction.perform('cache_spectrogram', {})
      }.to raise_error(ArgumentError, /CacheBase - Required parameter missing: uuid./)

    end
    it 'for audio' do
      expect {
        BawWorkers::MediaAction.perform('cache_audio', {})
      }.to raise_error(ArgumentError, /CacheBase - Required parameter missing: uuid./)
    end
  end
end