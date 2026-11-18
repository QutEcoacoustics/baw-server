# frozen_string_literal: true

# Include after defining the group's truth_table.
RSpec.shared_context 'with verification states' do
  # The seed data in this group is created once for the whole group, not once per example, because the truth table is
  # slow to build. So examples must treat it as read-only.
  # It builds its own project rather than using create_audio_recordings_hierarchy, which would rebuild it per example.
  let_it_be(:owner_user) { create(:user, user_name: 'owner user') }
  let_it_be(:project) { Creation::Common.create_project(owner_user) }
  let_it_be(:region) { Creation::Common.create_region(owner_user, project) }
  let_it_be(:site) { Creation::Common.create_site(owner_user, project, region:) }
  let_it_be(:audio_recording) { Creation::Common.create_audio_recording(owner_user, owner_user, site) }

  def self.truth_cells
    lines = truth_table.lines.map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
    lines.map { |line| line.tr('‖', '|').delete_prefix('|').delete_suffix('|').split('|', -1).map(&:strip) }
  end

  # Reads the truth table into { a1: { tags: [:t1, :t2], verifications: [[:u1, :t1, 'correct'], ...] }, ... }
  def self.truth_rows
    header, *body = truth_cells

    duplicates = body.map(&:first).tally.select { |_name, count| count > 1 }.keys
    raise ArgumentError, "Duplicate events in the truth table: #{duplicates.join(', ')}" if duplicates.any?

    body.to_h { |name, *cells| [name.to_sym, parse_truth_row(name, header.drop(1), cells)] }
  end

  def self.parse_truth_row(name, columns, cells)
    raise ArgumentError, "#{name} has #{cells.size} cells, expected #{columns.size}" if cells.size != columns.size

    filled = columns.zip(cells).reject { |_column, cell| cell.empty? }
    verifications, tags = filled.partition { |column, _cell| column.include?(':') }

    {
      tags: tags.map { |column, cell| parse_tag_cell(name, column, cell) },
      verifications: verifications.map { |column, cell| parse_verification_cell(name, column, cell) }
    }
  end

  def self.parse_tag_cell(name, column, cell)
    raise ArgumentError, "#{name} #{column}: expected x or blank, got '#{cell}'" unless cell == 'x'

    column.to_sym
  end

  def self.parse_verification_cell(name, column, cell)
    confirmation = { 'C' => 'correct', 'I' => 'incorrect', 'U' => 'unsure', 'S' => 'skip' }.fetch(cell) {
      raise ArgumentError, "#{name} #{column}: '#{cell}' is not a verification"
    }

    user, tag = column.split(':')
    [user.to_sym, tag.to_sym, confirmation]
  end

  # these names are the column headers in the truth table
  let_it_be(:u1) { create(:user, user_name: 'u1', skip_creation_email: true) }
  let_it_be(:u2) { create(:user, user_name: 'u2', skip_creation_email: true) }
  # verifying needs write access
  let_it_be(:u1_permission) { create(:write_permission, creator: owner_user, user: u1, project:) }
  let_it_be(:u2_permission) { create(:write_permission, creator: owner_user, user: u2, project:) }
  let_it_be(:u1_token) { Creation::Common.create_user_token(u1) }
  let_it_be(:t1) { create(:tag, creator: owner_user) }
  let_it_be(:t2) { create(:tag, creator: owner_user) }
  let_it_be(:t3) { create(:tag, creator: owner_user) }

  let_it_be(:events) do
    tags = { t1:, t2:, t3: }
    users = { u1:, u2: }

    self.class.truth_rows.transform_values do |row|
      event = create(:audio_event, audio_recording:, creator: owner_user)
      row[:tags].each { |tag| create(:tagging, audio_event: event, tag: tags.fetch(tag), creator: owner_user) }
      row[:verifications].each do |user, tag, confirmed|
        create(:verification, audio_event: event, tag: tags.fetch(tag), creator: users.fetch(user), confirmed:)
      end
      event
    end
  end

  truth_rows.each_key { |name| let(name) { events.fetch(name) } }

  def expect_matching_events(filter, *expected_event_name_suffixes)
    expected_names = expected_event_name_suffixes
      .flat_map { |suffix| suffix.is_a?(Range) ? suffix.to_a : suffix }
      .map { |suffix| :"a#{suffix}" }

    expected_events = expected_names.map { events.fetch(_1) }

    post '/audio_events/filter?disable_paging=true',
      params: { filter:, projection: { only: [:id] } },
      **api_with_body_headers(u1_token)

    expect_success

    aggregate_failures do
      expect(api_data.pluck(:id)).to match_array(expected_events.map(&:id))

      # This expectation is redundant but it makes it easier to debug which events were expected versus which were returned
      actual_names = api_data.pluck(:id).map { |id| events.key(events.values.find { |e| e.id == id }) }
      expect(actual_names).to match_array(expected_names)
    end
  end
end
