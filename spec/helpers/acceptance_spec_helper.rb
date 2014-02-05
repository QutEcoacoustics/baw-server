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
      expect(lat.to_s.split('.').last.size).to eq(2), "expected latitude to be obfuscated to two decimal places, got #{lat}"
      expect(long.to_s.split('.').last.size).to eq(2), "expected longitude to be obfuscated to two decimal places, got #{long}"
    else
      expect(lat.to_s.split('.').last.size).to be > 2, "expected latitude to be untouched, got #{lat}"
      expect(long.to_s.split('.').last.size).to be > 2, "expected longitude to be untouched, got #{long}"
    end
  end
end