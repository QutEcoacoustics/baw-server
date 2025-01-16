# frozen_string_literal: true

RSpec::Matchers.define :string_to_have_encoding do |expected_encoding|
  match do |actual|
    actual.is_a?(String) && actual.encoding == expected_encoding
  end

  failure_message do |actual|
    next "expected `#{actual}` to be a String but was a #{actual.class}" unless actual.is_a?(String)

    "expected that `#{actual}` would have encoding `#{expected_encoding}` but was `#{actual.encoding}`"
  end

  failure_message_when_negated do |actual|
    next "expected `#{actual}` to be a String but was a #{actual.class}" unless actual.is_a?(String)

    "expected that `#{actual}` would not have encoding `#{expected_encoding}` but was `#{actual.encoding}`"
  end

  description do
    "have encoding #{expected_encoding}"
  end
end
