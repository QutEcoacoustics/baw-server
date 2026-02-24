# frozen_string_literal: true

describe 'audio_events/download performance', :clean_by_truncation, :slow do
  create_entire_hierarchy

  # Number of audio events to create for the benchmark
  # Issue #892 mentions >1M events causing timeouts
  # We use a smaller number to keep tests reasonable while still measuring performance,
  # but this was tested with 1M events to verify the performance improvement.
  let(:event_count) {
    # 1_000_000
    10_000
  }

  # initial testing was done on 1M events, hence benchmarks are scaled off of that benchmark.
  # This test verifies that downloading annotations for a large dataset
  # completes within a reasonable time. Before optimization, downloading
  # >1M events would cause the web server to timeout.
  # Before optimization this test would take 106 seconds to run.
  # We're at less than 15ish seconds for CSV and 20 for JSON, so that's a 7x improvement.
  # base offset for standard request overhead, and some scaled offset for CI variability
  let(:baseline_performance) { 0.045 }
  let(:csv_expected_performance) { (event_count * (20.0 / 1_000_000)) + baseline_performance }
  let(:json_expected_performance) { (event_count * (40.0 / 1_000_000)) + baseline_performance }

  before do
    AudioEvent.delete_all

    # Create a large number of audio events efficiently using raw SQL
    duplicate_audio_events(event_count)
  end

  def duplicate_audio_events(count)
    # Get column names excluding id (auto-generated)
    columns = (AudioEvent.column_names - ['id']).join(', ')

    # Create the base audio event first
    base_event = create(:audio_event, audio_recording:, creator: writer_user)

    duplicate_rows_query = <<~SQL.squish
      INSERT INTO audio_events (#{columns})
      (
        SELECT #{columns}
        FROM (
          SELECT #{columns} FROM audio_events WHERE id = #{base_event.id}
        ) AS base_row
        CROSS JOIN LATERAL generate_series(1, #{count - 1}) series(index)
      )
    SQL
    ActiveRecord::Base.connection.execute(duplicate_rows_query)

    # Verify the count
    expect(AudioEvent.count).to eq(count)
  end

  def download_url(from:, format: :csv)
    base = case from
           when :projects
             "/projects/#{project.id}/audio_events/download"
           when :regions
             "/projects/#{project.id}/regions/#{region.id}/audio_events/download"
           when :sites
             "/projects/#{project.id}/sites/#{site.id}/audio_events/download"
           else
             raise ArgumentError, "Unknown download type: #{from}"
           end
    format == :json ? "#{base}.json" : base
  end

  describe 'for project downloads' do
    it 'performs quickly with many audio events' do
      expect {
        get download_url(from: :projects), params: nil, headers: auth_header(owner_token)
      }.to perform_under(csv_expected_performance).sec

      expect_success
      expect(response.content_type).to include('text/csv')

      # # Count the number of lines (header + events)
      # # CSV response should have header row + event_count data rows
      line_count = response.body.lines.count

      # # +1 for header
      expect(line_count).to eq(event_count + 1)
    end
  end

  describe 'for region downloads' do
    it 'performs quickly with many audio events' do
      expect {
        get download_url(from: :regions), params: nil, headers: auth_header(owner_token)
      }.to perform_under(csv_expected_performance).sec

      expect_success
      expect(response.content_type).to include('text/csv')

      line_count = response.body.lines.count
      expect(line_count).to eq(event_count + 1)
    end
  end

  describe 'for site downloads' do
    it 'performs quickly with many audio events' do
      expect {
        get download_url(from: :sites), params: nil, headers: auth_header(owner_token)
      }.to perform_under(csv_expected_performance).sec

      expect_success
      expect(response.content_type).to include('text/csv')

      line_count = response.body.lines.count
      expect(line_count).to eq(event_count + 1)
    end
  end

  describe 'for project downloads (JSON)' do
    it 'performs quickly with many audio events' do
      expect {
        get download_url(from: :projects, format: :json), params: nil, headers: auth_header(owner_token)
      }.to perform_under(json_expected_performance).sec

      expect_success
      expect(response.content_type).to include('application/json')

      body = response.parsed_body
      expect(body).to be_a(Hash)
      expect(body['columns']).to be_an(Array)
      expect(body['rows'].length).to eq(event_count)
    end
  end

  describe 'for site downloads (JSON)' do
    it 'performs quickly with many audio events' do
      expect {
        get download_url(from: :sites, format: :json), params: nil, headers: auth_header(owner_token)
      }.to perform_under(json_expected_performance).sec

      expect_success
      expect(response.content_type).to include('application/json')

      body = response.parsed_body
      expect(body).to be_a(Hash)
      expect(body['columns']).to be_an(Array)
      expect(body['rows'].length).to eq(event_count)
    end
  end
end
