require 'active_support/all'

require 'baw-audio-tools/version'
require 'baw-audio-tools/hash'
require 'baw-audio-tools/string'
require 'baw-audio-tools/OS'

module BawAudioTools

  autoload :Exceptions, 'baw-audio-tools/exceptions'
  autoload :CustomFormatter, 'baw-audio-tools/custom_formatter'
  autoload :Logging, 'baw-audio-tools/logging'

  autoload :AudioFfmpeg, 'baw-audio-tools/audio_ffmpeg'
  autoload :AudioMp3splt, 'baw-audio-tools/audio_mp3splt'
  autoload :AudioSox, 'baw-audio-tools/audio_sox'
  autoload :AudioWavpack, 'baw-audio-tools/audio_wavpack'
  autoload :AudioShntool, 'baw-audio-tools/audio_shntool'
  autoload :AudioBase, 'baw-audio-tools/audio_base'

  autoload :ImageImageMagick, 'baw-audio-tools/image_image_magick'
  autoload :Spectrogram, 'baw-audio-tools/spectrogram'

end