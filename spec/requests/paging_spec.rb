# frozen_string_literal: true

describe 'Paging totals in filter responses' do
  create_audio_recordings_hierarchy

  before do
    # The hierarchy already has one audio recording, so there are three in total.
    create_list(:audio_recording, 2, site:, creator: writer_user, uploader: writer_user)
  end

  def filter_audio_recordings(body)
    post '/audio_recordings/filter', params: body, **api_with_body_headers(writer_token)
    expect_success
  end

  it 'returns the first page of rows with the total number of matching rows' do
    filter_audio_recordings({ paging: { page: 1, items: 2 } })

    expect_number_of_items(2)
    expect_has_paging(page: 1, items: 2, total: 3)
  end

  it 'returns all rows and sets items to the total when paging is disabled' do
    filter_audio_recordings({ paging: { disable_paging: true } })

    expect_number_of_items(3)
    expect_has_paging(page: 1, items: 3, total: 3)
  end

  it 'returns no rows and a total of zero when no rows match on the first page' do
    filter_audio_recordings({ filter: { id: { eq: -1 } }, paging: { page: 1, items: 2 } })

    expect_number_of_items(0)
    expect_has_paging(page: 1, items: 2, total: 0)
  end

  it 'returns no rows and the total number of matching rows when the page is past the last row' do
    filter_audio_recordings({ paging: { page: 3, items: 2 } })

    expect_number_of_items(0)
    expect_has_paging(page: 3, items: 2, total: 3)
  end
end
