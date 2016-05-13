require 'spec_helper'

# tests audio file integrity functionality
describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  context 'verifying integrity' do
    context 'succeeds' do
      it 'processing valid .wv file' do
        temp_media_file_a = temp_media_file_1+'.wv'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:operation]).to eq('verified')
        expect(result[:info][:mode]).to eq('lossless')
      end

      it 'processing valid .mp3 file' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors][0][:description]).to eq('Skipping 0 bytes of junk at 253.')
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .asf file' do
        temp_media_file_a = temp_media_file_1+'.asf'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .wav file' do
        temp_media_file_a = temp_media_file_1+'.wav'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end


      it 'processing valid .flac file' do
        temp_media_file_a = temp_media_file_1+'.flac'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .ogg file' do
        temp_media_file_a = temp_media_file_1+'.ogg'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .wma file' do
        temp_media_file_a = temp_media_file_1+'.wma'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .webm file' do
        temp_media_file_a = temp_media_file_1+'.webm'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .webm file' do
        temp_media_file_a = temp_media_file_1+'.webm'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .wac file' do
        result = audio_base.integrity_check(audio_file_wac_2)
      end
    end
    context 'fails' do
      it 'processing empty .ogg file' do
        result = audio_base.integrity_check(audio_file_empty)

        expect(result[:errors].size).to eq(2)

        expect(result[:errors][0][:id]).to eq('ogg')
        expect(result[:errors][0][:description]).to eq('Format ogg detected only with low score of 1, misdetection possible!')

        expect(result[:errors][1][:id]).to eq('end of file')
        expect(result[:errors][1][:description]).to include('End of file')

      end

      it 'processing empty .mp3 file' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        FileUtils.touch(temp_media_file_a)

        result = audio_base.integrity_check(temp_media_file_a)

        expect(result[:errors].size).to eq(2)

        expect(result[:errors][0][:id]).to eq('mp3')
        expect(result[:errors][0][:description]).to eq('Format mp3 detected only with low score of 1, misdetection possible!')

        expect(result[:errors][1][:id]).to eq('mp3')
        expect(result[:errors][1][:description]).to eq('Could not find codec parameters for stream 0 (Audio: mp3, 0 channels, s16p): unspecified frame size')

      end

      it 'processing corrupt .ogg file' do

        result = audio_base.integrity_check(audio_file_corrupt)

        expect(result[:errors].size).to be > 1

        expect(result[:errors][0][:id]).to eq('Vorbis parser')
        expect(result[:errors][0][:description]).to eq('Invalid Setup header')

        expect(result[:errors][1][:id]).to eq('end of file')
        expect(result[:errors][1][:description]).to match(/End of file/)

        #expect(result[:errors][5][:id]).to eq('error')
        #expect(result[:errors][5][:description]).to include('Error while opening decoder for input stream #0:0 : Invalid data found when processing input')

      end
    end
  end
end