# expect(actual).to be(expected)

def check_regex_match(opts)

  actual = opts[:actual_response]
  expected = opts[:regex_match]

  unless expected.blank?
    fail ArgumentError, 'Must include :actual_response to check :regex_match' if actual.blank?

    if expected.respond_to?(:each)
      expected.each do |expected_regex_match|
        expect(actual).to match(expected_regex_match)
      end
    else
      expect(actual).to match(expected)
    end
  end

end

def check_response_content(opts, message_prefix)

  actual = opts[:actual_response]
  expected = opts[:response_body_content]

  unless expected.blank?
    if expected.respond_to?(:each)
      expected.each do |expected_content_item|
        expect(actual).to include(expected_content_item), "#{message_prefix} to find:\n\n'#{expected_content_item}'\n\nin:\n\n'#{actual}'"
      end
    else
      expect(actual).to include(expected), "#{message_prefix} to find:\n\n'#{expected}'\n\nin:\n\n'#{actual}'"
    end

  end

end

def check_invalid_content(opts, message_prefix)

  actual = opts[:actual_response]
  expected = opts[:invalid_content]

  unless expected.blank?
    if expected.respond_to?(:each)
      expected.each do |invalid_content_item|
        expect(actual).to_not include(invalid_content_item), "#{message_prefix} not to find '#{invalid_content_item}' in '#{actual}'"
      end
    else
      expect(actual).to_not include(expected), "#{message_prefix} not to find '#{expected}' in '#{actual}'"
    end

  end
end

def check_invalid_data_content(opts, message_prefix, parsed_response)

  expected = opts[:invalid_data_content]

  if !expected.blank? && !parsed_response.blank?
    actual = parsed_response['data'].to_json
    if expected.respond_to?(:each)
      expected.each do |invalid_content_item|
        expect(actual).to_not include(invalid_content_item), "#{message_prefix} not to find '#{invalid_content_item}' in '#{actual}'"
      end
    else
      expect(actual).to_not include(expected), "#{message_prefix} not to find '#{expected}' in '#{actual}'"
    end

  end
end