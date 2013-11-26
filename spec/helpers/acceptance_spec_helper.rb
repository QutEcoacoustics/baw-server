
def standard_request(description, expected_status, expected_json_path, document)

  # Execute request with ids defined in above let(:id) statements
  example "#{description} - #{expected_status}", :document => document do
    do_request
    status.should eq(expected_status), "expected status #{expected_status} but was #{status}. Response body was #{response_body}"
    unless expected_json_path.blank?
      response_body.should have_json_path(expected_json_path), "could not find #{expected_json_path} in #{response_body}"
    end
  end

end

def standard_request_with_explanation(description, expected_status, expected_json_path, document, explanation)

  # Execute request with ids defined in above let(:id) statements
  example "#{description} - #{expected_status}", :document => document do
    explanation(explanation)
    do_request
    status.should == expected_status
    unless expected_json_path.blank?
      response_body.should have_json_path(expected_json_path)
    end
  end

end