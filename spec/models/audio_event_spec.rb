# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_events
#
#  id                                                                              :integer          not null, primary key
#  channel                                                                         :integer
#  deleted_at                                                                      :datetime
#  end_time_seconds                                                                :decimal(10, 4)
#  high_frequency_hertz                                                            :decimal(10, 4)
#  import_file_index(Index of the row/entry in the file that generated this event) :integer
#  is_reference                                                                    :boolean          default(FALSE), not null
#  low_frequency_hertz                                                             :decimal(10, 4)
#  score(Score or confidence for this event.)                                      :decimal(, )
#  start_time_seconds                                                              :decimal(10, 4)   not null
#  created_at                                                                      :datetime
#  updated_at                                                                      :datetime
#  audio_event_import_file_id                                                      :bigint
#  audio_recording_id                                                              :integer          not null
#  creator_id                                                                      :integer          not null
#  deleter_id                                                                      :integer
#  provenance_id(Source of this event)                                             :integer
#  updater_id                                                                      :integer
#
# Indexes
#
#  index_audio_events_on_audio_event_import_file_id  (audio_event_import_file_id)
#  index_audio_events_on_audio_recording_id          (audio_recording_id)
#  index_audio_events_on_creator_id                  (creator_id)
#  index_audio_events_on_deleter_id                  (deleter_id)
#  index_audio_events_on_provenance_id               (provenance_id)
#  index_audio_events_on_updater_id                  (updater_id)
#
# Foreign Keys
#
#  audio_events_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  audio_events_creator_id_fk          (creator_id => users.id)
#  audio_events_deleter_id_fk          (deleter_id => users.id)
#  audio_events_updater_id_fk          (updater_id => users.id)
#  fk_rails_...                        (audio_event_import_file_id => audio_event_import_files.id) ON DELETE => cascade
#  fk_rails_...                        (provenance_id => provenances.id)
#
describe AudioEvent do
  subject { build(:audio_event) }

  it 'has a valid factory' do
    expect(create(:audio_event)).to be_valid
  end

  it 'can have a blank end time' do
    ae = build(:audio_event, end_time_seconds: nil)
    expect(ae).to be_valid
  end

  it 'can have a blank high frequency' do
    expect(build(:audio_event, high_frequency_hertz: nil)).to be_valid
  end

  it 'can have a blank end time and a blank high frequency' do
    expect(build(:audio_event, { end_time_seconds: nil, high_frequency_hertz: nil })).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:audio_event_import_file).optional }
  it { is_expected.to belong_to(:provenance).optional }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }
  it { is_expected.to belong_to(:deleter).optional }

  it { is_expected.to have_many(:tags) }
  # AT 2021: disabled. Nested associations are extremely complex,
  # and as far as we are aware, they are not used anywhere in production
  it { is_expected.not_to accept_nested_attributes_for(:tags) }

  # this test is not possible, since everything is converted to a bool when set to :is_reference...
  #it { is_expected.to validate_inclusion_of(:is_reference).in_array([true, false]) }

  it { is_expected.to validate_presence_of(:start_time_seconds) }
  it { is_expected.to validate_numericality_of(:start_time_seconds).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:end_time_seconds).is_greater_than_or_equal_to(0).allow_nil }

  it { is_expected.to validate_numericality_of(:low_frequency_hertz).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:high_frequency_hertz).is_greater_than_or_equal_to(0).allow_nil }

  it 'is invalid if the end time is less than the start time' do
    expect(build(:audio_event, { start_time_seconds: 100.320, end_time_seconds: 10.360 })).not_to be_valid
  end

  it 'is invalid if the end frequency is less then the low frequency' do
    expect(build(:audio_event, { low_frequency_hertz: 1000, high_frequency_hertz: 100 })).not_to be_valid
  end

  it 'has a recent scope' do
    create_list(:audio_event, 20)

    events = AudioEvent.most_recent(5).to_a
    expect(events).to have(5).items
    expect(AudioEvent.order(created_at: :desc).limit(5).to_a).to eq(events)
  end

  it 'has a total duration scope' do
    create_list(:audio_event, 10) do |item|
      item.start_time_seconds = 0
      item.end_time_seconds = 60
      item.save!
    end

    total = AudioEvent.total_duration_seconds
    expect(total).to an_instance_of(BigDecimal)
    expect(total).to eq(600)
  end

  it 'has a recent_within scope' do
    old = create(:audio_event, created_at: 2.months.ago)

    actual = AudioEvent.created_within(1.month.ago)
    expect(actual.count).to eq(AudioEvent.count - 1)
    expect(actual).not_to include(old)
  end

  context 'with arel scopes' do
    let!(:audio_recording) {
      create(:audio_recording, recorded_date: Time.zone.parse('2023-10-01 12:00:00'))
    }

    let!(:audio_event) {
      create(:audio_event, start_time_seconds: 123.456, end_time_seconds: 456.789, audio_recording:)
    }

    let(:event) {
      AudioEvent
        .joins(:audio_recording)
        .select(
          AudioEvent.start_date_arel.as('start_date'),
          AudioEvent.end_date_arel.as('end_date')
        )
        .find(audio_event.id)
    }

    it 'has a start_date arel expression' do
      expect(event.start_date).to eq(Time.zone.parse('2023-10-01 12:02:03.456'))
    end

    it 'has a end_date arel expression' do
      expect(event.end_date).to eq(Time.zone.parse('2023-10-01 12:07:36.789'))
    end
  end

  context 'with associated_taggings_arel' do
    create_audio_recordings_hierarchy

    let!(:audio_event) { create(:audio_event, :with_tags, audio_recording:) }

    it 'returns taggings as an array of hashes' do
      result = AudioEvent.select(:id, AudioEvent.associated_taggings_arel.as('taggings')).sole

      tagging = audio_event.taggings.sole.as_json

      expect(result.as_json).to match(
        a_hash_including(
          'id' => audio_event.id,
          'taggings' => a_kind_of(Array) & contain_exactly(
            a_hash_including(
              'id' => tagging['id'],
              'audio_event_id' => audio_event.id,
              'tag_id' => tagging['tag_id'],
              'created_at' => tagging['created_at'],
              'updated_at' => tagging['updated_at'],
              'creator_id' => tagging['creator_id'],
              'updater_id' => tagging['updater_id']
            )
          )
        )
      )
    end
  end

  context 'with associated_verification_ids_arel' do
    create_audio_recordings_hierarchy

    let!(:audio_event) { create(:audio_event, :with_tags, audio_recording:) }

    before do
      create(:verification, audio_event:, tag: audio_event.tags.first, creator: audio_event.creator)
    end

    it 'returns verifications as an array of ids' do
      result = AudioEvent.select(:id, AudioEvent.associated_verification_ids_arel.as('verification_ids')).sole

      verification_ids = [audio_event.verifications.sole.id]

      expect(result.as_json).to match(
        a_hash_including(
          'id' => audio_event.id,
          'verification_ids' => verification_ids
        )
      )
    end
  end

  context 'with verification_summary_arel' do
    create_audio_recordings_hierarchy

    let!(:audio_event) { create(:audio_event, :with_tags, audio_recording:) }
    let(:tag) { audio_event.tags.first }
    let(:tag2) { create(:tag, creator: audio_event.creator) }

    before do
      [
        [writer_user, tag, :correct],
        [reader_user, tag, :incorrect],
        [owner_user, tag, :skip],
        [harvester_user, tag, :unsure],
        [admin_user, tag, :correct],
        [writer_user, tag2, :correct],
        [admin_user, tag2, :correct]
      ].each do |creator, tag, confirmed|
        create(:verification, audio_event:, tag:, creator:, confirmed:)
      end
    end

    it 'returns verifications as an array of hashes' do
      result = AudioEvent.select(:id, AudioEvent.verification_summary_arel.as('verification_summary')).sole

      expect(result.as_json).to match(
        a_hash_including(
          'id' => audio_event.id,
          'verification_summary' => [
            {
              'tag_id' => tag.id,
              'count' => 5,
              'correct' => 2,
              'incorrect' => 1,
              'skip' => 1,
              'unsure' => 1
            },
            {
              'tag_id' => tag2.id,
              'count' => 2,
              'correct' => 2,
              'incorrect' => 0,
              'skip' => 0,
              'unsure' => 0
            }
          ]
        )
      )
    end
  end

  it 'constructs the expected sql for annotation download (timezone: UTC)' do
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, nil)
    sql = query.to_sql

    # verify four CTEs are present: event_filter first, then tags/verifications depend on it
    expect(sql).to include('WITH "event_filter_cte_table" AS')
    expect(sql).to include('"verification_cte_table" AS')
    expect(sql).to include('"tags_cte_table" AS')
    expect(sql).to include('"projects_cte_table" AS')

    # verify event_filter_cte is defined first in the WITH clause
    event_filter_pos = sql.index('"event_filter_cte_table" AS')
    verification_pos = sql.index('"verification_cte_table" AS')
    tags_pos = sql.index('"tags_cte_table" AS')
    expect(event_filter_pos).to be < verification_pos
    expect(event_filter_pos).to be < tags_pos

    # verify tags/verifications CTEs join on event_filter_cte_table
    expect(sql).to include('INNER JOIN "event_filter_cte_table" ON "audio_events_tags"."audio_event_id" = "event_filter_cte_table"."id"')
    expect(sql).to include('INNER JOIN "event_filter_cte_table" ON "verifications"."audio_event_id" = "event_filter_cte_table"."id"')

    # verify INNER JOIN on event_filter_cte_table
    expect(sql).to include('INNER JOIN "event_filter_cte_table"')

    # verify CTE-based columns replaced correlated subqueries
    expect(sql).to include('"tags_cte_table"."common_name_tags"')
    expect(sql).to include('"tags_cte_table"."species_name_tags"')
    expect(sql).to include('"tags_cte_table"."other_tags"')
    expect(sql).to include('"projects_cte_table"."projects"')

    # verify CTE joins
    expect(sql).to include('LEFT OUTER JOIN "tags_cte_table"')
    expect(sql).to include('LEFT OUTER JOIN "projects_cte_table"')

    # verify raw timestamps formatted via to_char
    expect(sql).to include('to_char')
    expect(sql).to include('audio_recording_start_date_utc_00_00')
    expect(sql).to include('event_created_at_date_utc_00_00')
    expect(sql).to include('event_start_date_utc_00_00')

    # verify users INNER JOIN removed
    expect(sql).not_to include('INNER JOIN "users"')

    # verify live projects filter is in the event_filter CTE (not the final query)
    expect(sql).to include('SELECT DISTINCT "projects_sites"."site_id" FROM "projects_sites"')

    # verify no correlated tag subqueries remain
    expect(sql).not_to match(/SELECT\s+string_agg.*FROM\s+"tags"\s+INNER\s+JOIN\s+"audio_events_tags"/)
  end

  it 'constructs the expected sql for annotation download (timezone: Brisbane)' do
    query =
      AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, 'Brisbane', nil)
    sql = query.to_sql

    # verify four CTEs are present
    expect(sql).to include('WITH "event_filter_cte_table" AS')
    expect(sql).to include('"verification_cte_table" AS')
    expect(sql).to include('"tags_cte_table" AS')
    expect(sql).to include('"projects_cte_table" AS')

    # verify CTE-based columns replaced correlated subqueries
    expect(sql).to include('"tags_cte_table"."common_name_tags"')
    expect(sql).to include('"projects_cte_table"."projects"')

    # verify to_char formatting with Brisbane timezone
    expect(sql).to include('to_char')
    expect(sql).to include('brisbane_10_00')
    expect(sql).to include("INTERVAL '36000 seconds'")

    # verify event_filter CTE and INNER JOIN
    expect(sql).to include('INNER JOIN "event_filter_cte_table"')
    expect(sql).to include('SELECT DISTINCT "projects_sites"."site_id" FROM "projects_sites"')
  end

  it 'excludes deleted projects, sites, audio_recordings, and audio_events from annotation download' do
    AudioEvent.delete_all
    user = create(:user, user_name: 'owner user checking excluding deleted items in annotation download')

    # create combinations of deleted and not deleted for project, site, audio_recording, audio_event
    expected_audio_event = nil
    2.times do |project_n|
      project = create(:project, creator: user)
      project.discard! if project_n == 1

      region = create(:region, creator: user, project: project)
      region.discard! if project_n == 1
      2.times do |site_n|
        site = create(:site, :with_lat_long, creator: user, projects: [project], region:)

        site.discard! if site_n == 1

        2.times do |audio_recording_n|
          audio_recording = create(:audio_recording, :status_ready, creator: user, uploader: user,
            site:)
          audio_recording.discard! if audio_recording_n == 1

          2.times do |audio_event_n|
            audio_event = create(:audio_event, creator: user, audio_recording:)
            audio_event.discard! if audio_event_n == 1
            if project_n == 0 && site_n == 0 && audio_recording_n == 0 && audio_event_n == 0
              expected_audio_event = audio_event
            end
          end
        end
      end
    end

    # check that AudioEvent.csv_query returns only non-deleted items
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, nil)
    query_sql = query.to_sql
    formatted_annotations = AudioEvent.connection.select_all(query_sql)

    expect(Project.with_discarded.count).to eq(2)
    expect(Project.count).to eq(1)
    expect(Project.discarded.count).to eq(1)

    expect(Region.with_discarded.count).to eq(2)
    expect(Region.count).to eq(1)
    expect(Region.discarded.count).to eq(1)

    expect(Site.with_discarded.count).to eq(4)
    expect(Site.count).to eq(2)
    expect(Site.discarded.count).to eq(2)

    expect(AudioRecording.with_discarded.count).to eq(8)
    expect(AudioRecording.count).to eq(4)
    expect(AudioRecording.discarded.count).to eq(4)

    expect(AudioEvent.with_discarded.count).to eq(16)
    expect(AudioEvent.count).to eq(8)
    expect(AudioEvent.discarded.count).to eq(8)

    expected_audio_events = [expected_audio_event.id]
    actual_audio_event_ids = formatted_annotations.pluck('audio_event_id')

    expect(actual_audio_event_ids).to eq(expected_audio_events)
  end

  it 'ensures only one instance of each audio event in annotation download' do
    user = create(:user, user_name: 'owner user checking audio event uniqueness in annotation download')

    # create 2 of everything for project, site, audio_recording, audio_event
    2.times do
      project = create(:project, creator: user)

      2.times do
        site = create(:site, :with_lat_long, creator: user)
        site.projects << project
        site.save!

        2.times do
          audio_recording = create(:audio_recording, :status_ready, creator: user, uploader: user,
            site:)

          create_list(:audio_event, 2, creator: user, audio_recording:)
        end
      end
    end

    # check that AudioEvent.csv_query returns unique audio events
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, nil)
    query_sql = query.to_sql
    formatted_annotations = AudioEvent.connection.select_all(query_sql)

    actual_audio_event_ids = formatted_annotations.pluck('audio_event_id')

    expect(actual_audio_event_ids.count).to eq(2 * 2 * 2 * 2)

    expected_audio_event_ids = actual_audio_event_ids.uniq

    expect(actual_audio_event_ids).to eq(expected_audio_event_ids)
  end

  it 'includes events from sites that have no region in annotation download' do
    user = create(:user)
    other_site = create(:site, region: nil, creator: user)
    other_audio_recording = create(:audio_recording, site: other_site, creator: user)
    other_audio_event = create(:audio_event, audio_recording: other_audio_recording, creator: user)

    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, nil)
    returned_event_ids = AudioEvent.connection.select_all(query.to_sql).pluck('audio_event_id')

    expect(returned_event_ids).to eq([other_audio_event.id])
  end

  it 'includes score in csv_query results' do
    audio_event = create(:audio_event, score: 0.75)
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, nil)
    results = AudioEvent.connection.select_all(query.to_sql).to_a
    event = results.find { |r| r['audio_event_id'] == audio_event.id }
    expect(event).to include('score' => 0.75)
  end

  describe 'csv_query and imports' do
    create_entire_hierarchy

    it 'includes import details in annotation download' do
      query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, nil)
      results = AudioEvent.connection.select_all(query.to_sql).to_a

      first = results.first
      expect(first).to match(a_hash_including(
        'audio_event_import_file_id' => audio_event_import_file.id,
        'audio_event_import_file_name' => audio_event_import_file.name,
        'audio_event_import_id' => audio_event_import.id,
        'audio_event_import_name' => audio_event_import.name
      ))
    end

    it 'can filter by import in annotation download' do
      audio_event.update!(audio_event_import_file: audio_event_import_file)

      query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil, audio_event_import)
      results = AudioEvent.connection.select_all(query.to_sql).to_a
      expect(results.count).to eq(1)
      expect(results.first).to match(a_hash_including(
        'audio_event_id' => audio_event.id,
        'audio_event_import_file_id' => audio_event_import_file.id,
        'audio_event_import_id' => audio_event_import.id
      ))
    end
  end

  describe 'verifications query for csv_query' do
    create_entire_hierarchy

    # set up a new event, with two tags and taggings
    let(:event_one) { create(:audio_event, creator: writer_user, audio_recording:) }

    let(:tag_one) { create(:tag_taxonomic_true_common, creator: writer_user) }
    let(:tag_two) { create(:tag_taxonomic_true_common, creator: writer_user) }

    let(:tagging_one) {
      create(:tagging,
        audio_event_id: event_one.id,
        tag_id: tag_one.id,
        creator: writer_user)
    }
    let(:tagging_two) {
      create(:tagging,
        audio_event_id: event_one.id,
        tag_id: tag_two.id,
        creator: writer_user)
    }

    # the number of verifications to create for each `confirmed` value, for each tag
    let(:choices_one) {
      { Verification::CONFIRMATION_TRUE => 4,
        Verification::CONFIRMATION_FALSE => 3,
        Verification::CONFIRMATION_SKIP => 2,
        Verification::CONFIRMATION_UNSURE => 1 }
    }
    let(:choices_two) {
      { Verification::CONFIRMATION_TRUE => 1,
        Verification::CONFIRMATION_FALSE => 4,
        Verification::CONFIRMATION_SKIP => 3,
        Verification::CONFIRMATION_UNSURE => 2 }
    }

    # for the single audio_event `event_one`, with two tags / annotations:
    # create 10 verifications of tag one, and 10 verifications of tag two
    # each verification coming from a different user
    before do
      event_verifications_for_tagging(tagging_one, choices_one)
      event_verifications_for_tagging(tagging_two, choices_two)
    end

    it 'aggregates verifications from multiple tags correctly' do
      # Build an unfiltered event_filter CTE (selects all non-deleted audio_events)
      event_filter_cte_table, event_filter_cte = AudioEvent.audio_event_filter_cte(nil, nil, nil, nil, nil, nil, nil)
      verification_cte_table, query_cte = AudioEvent.verification_summary_cte(event_filter_cte_table)

      query = AudioEvent.arel_table.join(verification_cte_table)
        .on(AudioEvent.arel_table[:id].eq(verification_cte_table[:audio_event_id]))
        .project(verification_cte_table[Arel.star])
        .with(event_filter_cte, query_cte)

      results = AudioEvent.connection.select_all(query.to_sql)

      expect(results.pluck('verifications')).to eq([
        "#{tag.id}:#{tag.text}",
        "#{tag_one.id}:#{tag_one.text}|#{tag_two.id}:#{tag_two.text}"
      ])

      expect(results.pluck('verification_counts')).to eq([
        audio_event.verifications.count.to_s,
        [event_one.verifications.where(tag: tag_one.id).count.to_s,
         event_one.verifications.where(tag: tag_two.id).count.to_s].join('|')
      ])

      [
        Verification::CONFIRMATION_TRUE,
        Verification::CONFIRMATION_FALSE,
        Verification::CONFIRMATION_SKIP,
        Verification::CONFIRMATION_UNSURE
      ].each do |value|
        eq([audio_event.verifications.where(confirmed: value).count.to_s,
            [event_one.verifications.where(tag: tag_one.id, confirmed: value).count,
             event_one.verifications.where(tag: tag_two.id, confirmed: value).count].map(&:to_s).join('|')])
      end

      expect(results.pluck('verification_decisions')).to eq([
        verification.confirmed,
        [choices_one.max_by { |_k, v| v }.first,
         choices_two.max_by { |_k, v| v }.first].join('|')
      ])

      expect(results.pluck('verification_consensus')).to eq([
        '1.00',
        [format('%.2f', choices_one.values.max / choices_one.values.sum.to_f),
         format('%.2f', choices_two.values.max / choices_two.values.sum.to_f)].join('|')
      ])
    end
  end

  it_behaves_like 'cascade deletes for', :audio_event, {
    taggings: nil,
    comments: nil,
    verifications: nil
  } do
    create_entire_hierarchy
  end
end

def event_verifications_for_tagging(tagging, choices)
  choices.each do |choice, number|
    number.times do |_i|
      create(:verification,
        audio_event_id: tagging.audio_event_id,
        tag_id: tagging.tag_id,
        creator: create(:user),
        confirmed: choice)
    end
  end
end
