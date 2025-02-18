# frozen_string_literal: true

describe Api::AudioEventParser::KeyTransformer do
  extend Dry::Monads[:maybe]

  # Reminder: the transformers are meant to normalize valid values.
  # Invalid values should be unaffected and should be passed onto the validation step
  # which can generate better error messages with the original value.
  #
  # Blank values are handled outside of the transformers.
  # But we still test here to make sure the transformers don't break when given blank values.

  let(:int) { Api::AudioEventParser::IntTransformer.new }
  let(:int?) { Api::AudioEventParser::IntTransformer.new(allow_nil: true) }
  let(:float) { Api::AudioEventParser::FloatTransformer.new }
  let(:float?) { Api::AudioEventParser::FloatTransformer.new(allow_nil: true) }
  let(:bool) { Api::AudioEventParser::BoolTransformer.new }
  let(:bool?) { Api::AudioEventParser::BoolTransformer.new(allow_nil: true) }
  let(:tag) { Api::AudioEventParser::TagTransformer.new }
  let(:friendly_identifier) { Api::AudioEventParser::FriendlyAudioRecordingNameTransformer.new }

  [
    [:int, 1, Some(1)],
    [:int, '1', Some(1)],
    [:int, '1.0', None()],
    [:int, nil, None()],
    [:int, '', None()],
    [:int, 'a', None()],
    [:int?, 1, Some(1)],
    [:int?, nil, None()],
    [:int?, '', None()],
    [:float, 1.0, Some(1.0)],
    [:float, '1.0', Some(1.0)],
    [:float, '1', Some(1.0)],
    [:float, nil, None()],
    [:float, '', None()],
    [:float, 'a', None()],
    [:float?, 1.0, Some(1.0)],
    [:float?, nil, None()],
    [:float?, '', None()],
    [:bool, true, Some(true)],
    [:bool, 'true', Some(true)],
    [:bool, 'false', Some(false)],
    [:bool, '1', Some(true)],
    [:bool, '0', Some(false)],
    [:bool, nil, None()],
    [:bool, '', None()],
    [:bool, 'a', None()],
    [:bool?, true, Some(true)],
    [:bool?, nil, None()],
    [:bool?, '', None()],
    [:bool?, 'a', None()],
    [:tag, 'tag', Some('tag')],
    [:tag, 'tag;tag2', Some(['tag', 'tag2'])],
    [:tag, 'tag;tag2;', Some(['tag', 'tag2'])],
    [:tag, nil, None()],
    [:tag, '', None()],
    [:tag, '1:a|2:b', Some(['a', 'b'])],
    [:tag, '1:a|2:c|', Some(['a', 'c'])],
    [:friendly_identifier, '20000101T000000Z_abc_123456.wav', Some(123_456)],
    [:friendly_identifier, '20000101T000000Z_abc_123456', None()],
    [:friendly_identifier, '20000101T000000Z_abc_abc.wav', None()],
    [:friendly_identifier, nil, None()]
  ].each do |type, value, expected|
    it "can transform #{type} values, case: `#{value.inspect}`" do
      transformer = send(type)
      expect(transformer.transform(:key, value)).to eq(expected)
    end
  end
end
