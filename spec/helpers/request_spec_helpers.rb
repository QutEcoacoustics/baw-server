# frozen_string_literal: true

# config.extend allows these methods to be used in describe/context groups
module RequestSpecExampleGroupHelpers
end

# config.include allows these methods to be used in specs/before/let
module RequestSpecExampleHelpers
  def api_request_headers(token, send_body: false, content_type: 'application/json')
    headers = {
      'ACCEPT' => 'application/json',
      'HTTP_AUTHORIZATION' => token
    }
    headers['CONTENT_TYPE'] = content_type if send_body
    headers
  end

  def response_body
    # the != false is not redundant here... safe access could result in nil
    # which would evaluate to false and execute wrong half of conditional
    @response_body ||= response&.body&.empty? != false ? nil : response.body
  end

  def api_result
    @api_result ||= response_body.nil? ? nil : JSON.parse(response_body, symbolize_names: true)
  end

  def expect_json_response
    expect(response.content_type).to eq('application/json; charset=utf-8')
  end

  def expect_id_matches(expected)
    id = get_id(expected)
    expect(api_result).to include({ data: hash_including({ id: id }) })
  end

  def expect_has_ids(*expected)
    expect(api_result[:data]).to be_a(Array)

    expected = expected.flatten

    if expected.empty?
      expect(api_result[:data]).to match([])
    else
      inner = expected
              .map { |x| hash_including({ id: get_id(x) }) }
              .to_a

      expect(api_result).to include(data: match_array(inner))
    end
  end

  def expect_at_least_one_item
    expect(api_result[:data]).to be_a(Array)
    api_result[:data].should have_at_least(1).items
  end

  def expect_zero_items
    expect_number_of_items(0)
  end

  def expect_number_of_items(n)
    expect(api_result[:data]).to be_a(Array)
    api_result[:data].should have(n).items
  end

  def expect_empty_body
    expect(response.body).to be_empty
  end

  def expect_data_is_hash
    data = api_result[:data]
    expect(data).to be_a(Hash)
    expect(data).to_not be_empty
  end

  def expect_data_is_hash_with_any_id
    expect(api_result).to include({
      data: hash_including({ id: a_kind_of(Integer) })
    })
  end

  def expect_has_projection(projection)
    expect(api_result).to include(meta: hash_including({
      projection: projection
    }))
  end

  def expect_has_paging(page: 0, items: 25, current: nil, total: nil)
    expected = {
      items: items,
      page: page
    }
    expected[:current] = current unless current.nil?
    expected[:total] = total unless total.nil?
    expect(api_result).to include(meta: hash_including({
      paging: hash_including(expected)
    }))
  end

  def expect_has_sorting(order_by:, direction: 'asc')
    expect(api_result).to include(meta: hash_including({
      sorting: {
        direction: direction,
        order_by: order_by
      }
    }))
  end

  def expect_has_filter(_filter)
    expect(api_result).to include(meta: hash_including({
      filter: projection
    }))
  end

  def expect_success
    expect(response).to have_http_status(:success)
  end

  def expect_error(status, details)
    aggregate_failures 'error response' do
      expect_json_response

      message =
        case status
        when 400
          'Bad Request'
        when 404
          'Not Found'
        else
          raise "Message not yet implemented for status #{status}"
        end

      expect(api_result).to match({
        meta: hash_including({
          status: status,
          message: message,
          error: hash_including({
            details: details
          })
        }),
        data: nil
      })
    end
  end

  def expect_headers_to_include(expected)
    expect(response.headers).to match(hash_including(expected))
  end

  def self.included(base); end

  private

  def get_id(anything)
    case anything
    when nil, Integer
      anything
    when ActiveRecord::Base, ->(x) { x.respond_to?(:id) }
      anything.id
    when Hash
      anything[:id] if anything.key?(:id)
      anything['id'] if anything.key?('id')
    else
      anything
    end
  end
end
