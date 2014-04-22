def standard_request(description, expected_status, expected_json_path, document, response_body_content = nil)
  # Execute request with ids defined in above let(:id) statements
  example "#{description} - #{expected_status}", :document => document do
    do_request
    status.should eq(expected_status), "expected status #{expected_status} but was #{status}. Response body was #{response_body}"
    unless expected_json_path.blank?
      response_body.should have_json_path(expected_json_path), "could not find #{expected_json_path} in #{response_body}"
    end
    unless response_body_content.blank?
      expect(response_body).to include(response_body_content)
    end

    if block_given?
      yield(response_body)
    end

    response_body
  end
end

def check_site_lat_long_response(description, expected_status, should_be_obfuscated = true)
  example "#{description} - #{expected_status}", document: false do
    do_request
    status.should eq(expected_status), "expected status #{expected_status} but was #{status}. Response body was #{response_body}"
    response_body.should have_json_path('location_obfuscated'), response_body.to_s
    #response_body.should have_json_type(Boolean).at_path('location_obfuscated'), response_body.to_s
    site = JSON.parse(response_body)

    #'Accurate to with a kilometre (± 1000m)'

    lat = site['latitude']
    long = site['longitude']

    if should_be_obfuscated
      min = 4
      max = 6
      expect(lat.to_s.split('.').last.size)
      .to satisfy { |v| v >= min && v <= max },
          "expected latitude to be obfuscated to between #{min} to #{max} places, "+
              "got #{lat.to_s.split('.').last.size} from #{lat}"

      expect(long.to_s.split('.').last.size)
      .to satisfy { |v| v >= min && v <= max },
          "expected longitude to be obfuscated to between #{min} to #{max} places, "+
              "got #{long.to_s.split('.').last.size} from #{long}"
    end
  end
end