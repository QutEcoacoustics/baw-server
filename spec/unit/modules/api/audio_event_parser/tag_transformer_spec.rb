# frozen_string_literal: true

require_relative 'audio_event_parser_context'
describe Api::AudioEventParser::TagTransformer do
  include_context 'audio_event_parser'

  describe 'multiple tags' do
    it 'trims whitespace from tags' do
      transformer = Api::AudioEventParser::TagTransformer.new(:tags)
      values = {
        tags: " tag ala tag\t"
      }
      result = transformer.extract_key(values)
      expect(result).to eq(Dry::Monads::Maybe(['tag ala tag']))
    end

    it 'trims whitespace from tags after splitting' do
      transformer = Api::AudioEventParser::TagTransformer.new(:tags)
      values = {
        tags: " tag1;\ttarget 2 ;    tag3\t"
      }
      result = transformer.extract_key(values)
      expect(result).to eq(Dry::Monads::Maybe(['tag1', 'target 2', 'tag3']))
    end
  end
end
