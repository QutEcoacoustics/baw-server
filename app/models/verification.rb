# frozen_string_literal: true

# A Verification represents a user's confirmation that a tag is correctly
# applied to an audio event.
# @see (#AudioEvent) and (#Tag) for more information on these models.
#
# == Schema Information
#
# Table name: verifications
#
#  id             :bigint           not null, primary key
#  confirmed      :enum             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  audio_event_id :bigint           not null
#  creator_id     :integer          not null
#  tag_id         :bigint           not null
#  updater_id     :integer
#
# Indexes
#
#  idx_on_audio_event_id_tag_id_creator_id_f944f25f20  (audio_event_id,tag_id,creator_id) UNIQUE
#  index_verifications_on_audio_event_id               (audio_event_id)
#  index_verifications_on_tag_id                       (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_event_id => audio_events.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (tag_id => tags.id) ON DELETE => cascade
#  fk_rails_...  (updater_id => users.id)
#
class Verification < ApplicationRecord
  include Api::Stats

  belongs_to :audio_event, inverse_of: :verifications
  belongs_to :tag, inverse_of: :verifications
  belongs_to :creator, class_name: 'User', inverse_of: :created_verifications
  belongs_to :updater, class_name: 'User', inverse_of: :updated_verifications, optional: true

  # Defines the possible values for confirmation
  CONFIRMATION_TRUE = 'correct'
  CONFIRMATION_FALSE = 'incorrect'
  CONFIRMATION_UNSURE = 'unsure'
  CONFIRMATION_SKIP = 'skip'

  # @type [Hash{String => String}]
  CONFIRMATION_ENUM = {
    CONFIRMATION_TRUE => CONFIRMATION_TRUE,
    CONFIRMATION_FALSE => CONFIRMATION_FALSE,
    CONFIRMATION_UNSURE => CONFIRMATION_UNSURE,
    CONFIRMATION_SKIP => CONFIRMATION_SKIP
  }.freeze

  # @!method confirmed_true?
  #   @return [Boolean] true if the verification is confirmed as true
  # @!method confirmed_true!
  #   @return [void] sets the verification as confirmed true
  # @!method confirmed_false?
  #   @return [Boolean] true if the verification is confirmed as false
  # @!method confirmed_false!
  #   @return [void] sets the verification as confirmed false
  # @!method confirmed_unsure?
  #   @return [Boolean] true if the verification is marked as unsure
  # @!method confirmed_unsure!
  #   @return [void] sets the verification as unsure
  # @!method confirmed_skip?
  #   @return [Boolean] true if the verification is marked as skip
  # @!method confirmed_skip!
  #   @return [void] sets the verification as skip
  enum :confirmed, CONFIRMATION_ENUM, prefix: :confirmed, validate: true

  def self.filter_settings
    fields = [
      :id, :confirmed, :audio_event_id, :tag_id, :creator_id,
      :updater_id, :created_at, :updated_at
    ]

    {
      valid_fields: fields,
      render_fields: fields,
      text_fields: [],
      new_spec_fields: lambda { |_user|
        {
          confirmed: nil,
          audio_event_id: nil,
          tag_id: nil
        }
      },
      controller: :verifications,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      },
      valid_associations: [
        {
          join: AudioEvent,
          on: Verification.arel_table[:audio_event_id].eq(AudioEvent.arel_table[:id]),
          available: true,
          associations: [
            {
              join: AudioRecording,
              on: AudioEvent.arel_table[:audio_recording_id].eq(AudioRecording.arel_table[:id]),
              available: true,
              associations: [
                {
                  join: Site,
                  on: AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]),
                  available: true,
                  associations: [
                    {
                      join: Region,
                      on: Site.arel_table[:region_id].eq(Region.arel_table[:id]),
                      available: true
                      # TODO: re-enable when we finally remove projects_sites
                      # https://github.com/QutEcoacoustics/baw-server/issues/743
                      # associations: [
                      #   {
                      #     join: Project,
                      #     on: Region.arel_table[:project_id].eq(Project.arel_table[:id]),
                      #     available: true
                      #   }
                      # ]
                    },
                    {
                      join: ProjectsSite,
                      on: Site.arel_table[:id].eq(ProjectsSite.arel_table[:site_id]),
                      available: false,
                      associations: [
                        {
                          join: Project,
                          on: ProjectsSite.arel_table[:project_id].eq(Project.arel_table[:id]),
                          available: true
                        }
                      ]
                    }

                  ]
                }
              ]
            },
            {
              join: AudioEventImportFile,
              on: AudioEvent.arel_table[:audio_event_import_file_id].eq(AudioEventImportFile.arel_table[:id]),
              available: true,
              associations: [
                {
                  join: AudioEventImport,
                  on: AudioEventImportFile.arel_table[:audio_event_import_id].eq(AudioEventImport.arel_table[:id]),
                  available: true
                }
              ]
            }
          ]
        },
        {
          join: Tag,
          on: Verification.arel_table[:tag_id].eq(Tag.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        confirmed: {
          type: 'string',
          enum: CONFIRMATION_ENUM.values
        },
        audio_event_id: Api::Schema.id(read_only: false),
        tag_id: Api::Schema.id(read_only: false),
        **Api::Schema.updater_and_creator_user_stamps
      },
      required: [
        :id,
        :confirmed,
        :audio_event_id,
        :tag_id,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at
      ]
    }.freeze
  end

  # TODO: first draft of query into arel - reduce size. Executes in ~4.5 seconds on the
  # usual reports benchmark scenario.
  #
  # Stats hook consumed by Api::Stats#execute_stats via the controller.
  #
  # @param user [User, nil] the requesting user
  # @return [Proc] a callable that reshapes the filtered query for stats
  def self.stats_hook(user = nil)
    user_id = user&.id

    lambda do |query|
      base_table = Arel::Table.new('base')
      base_cte = Arel::Nodes::As.new(base_table, query.arel)

      # Per-user verification counts, ranked highest first.
      ranked_leaderboard_subquery = Arel::SelectManager.new
        .project(
          base_table[:creator_id].as('user_id'),
          base_table[:id].count.as('verification_count')
        )
        .from(base_table)
        .group(base_table[:creator_id])

      ranked_leaderboard_source = ranked_leaderboard_subquery.as('leaderboard_counts')
      ranked_leaderboard = Arel::SelectManager.new
        .project(
          ranked_leaderboard_source[:user_id],
          ranked_leaderboard_source[:verification_count],
          Arel.sql('RANK() OVER (ORDER BY verification_count DESC) AS rank')
        )
        .from(ranked_leaderboard_source)

      ranked_leaderboard_table = Arel::Table.new('ranked_leaderboard')
      ranked_leaderboard_cte = Arel::Nodes::As.new(ranked_leaderboard_table, ranked_leaderboard)

      # Top 5 of the leaderboard
      leaderboard_top = Arel::SelectManager.new
        .project(
          ranked_leaderboard_table[:user_id],
          ranked_leaderboard_table[:verification_count],
          ranked_leaderboard_table[:rank]
        )
        .from(ranked_leaderboard_table)
        .where(ranked_leaderboard_table[:rank].lteq(5))

      # The requesting user, if they have verifications but fall outside the top 5
      leaderboard_request_user = Arel::SelectManager.new
        .project(
          ranked_leaderboard_table[:user_id],
          ranked_leaderboard_table[:verification_count],
          ranked_leaderboard_table[:rank]
        )
        .from(ranked_leaderboard_table)
        .where(ranked_leaderboard_table[:user_id].eq(user_id).and(ranked_leaderboard_table[:rank].gt(5)))

      # The requesting user with a zero count and null rank, if they have no verifications
      request_user_exists = Arel::SelectManager.new
        .project(Arel.sql('1'))
        .from(ranked_leaderboard_table)
        .where(ranked_leaderboard_table[:user_id].eq(user_id))

      leaderboard_request_user_absent = Arel::SelectManager.new
        .project(Arel::Nodes.build_quoted(user_id), 0, Arel::Nodes.build_quoted(nil))
        .where(request_user_exists.exists.not)

      leaderboard_rows = Arel::Nodes::UnionAll.new(
        leaderboard_top.union(:all, leaderboard_request_user),
        leaderboard_request_user_absent.ast
      )
      leaderboard_rows_table = Arel::Table.new('leaderboard_rows')
      leaderboard_rows_cte = Arel::Nodes::As.new(leaderboard_rows_table, leaderboard_rows)

      # Distribution of how many users verified each tagging (audio_event + tag).
      verification_counts_by_tagging_subquery = base_table
        .project(
          base_table[:audio_event_id],
          base_table[:tag_id],
          base_table[:id].count.as('verification_count')
        )
        .group(base_table[:audio_event_id], base_table[:tag_id])

      verification_counts_by_tagging_source = verification_counts_by_tagging_subquery.as('verification_counts_by_tagging')
      count = verification_counts_by_tagging_source[:verification_count]

      overrun_distribution = Arel::SelectManager.new
        .project(
          Arel::Nodes::NamedFunction.new('json_build_array', [
            Arel.json({ run: 1, count: Arel.star.count.filter(count.eq(1)) }),
            Arel.json({ run: 2, count: Arel.star.count.filter(count.eq(2)) }),
            Arel.json({ run: 3, count: Arel.star.count.filter(count.eq(3)) }),
            Arel.json({ run: 4, count: Arel.star.count.filter(count.eq(4)) }),
            Arel.json({ run: 5, count: Arel.star.count.filter(count.gteq(5)), overflow: 'true' })
          ])
        )
        .from(verification_counts_by_tagging_source)

      leaderboard_object = Arel.json({
        user_id: leaderboard_rows_table[:user_id],
        verification_count: leaderboard_rows_table[:verification_count],
        rank: leaderboard_rows_table[:rank]
      })

      ordered_leaderboard_object = Arel::Nodes::InfixOperation.new(
        'ORDER BY', leaderboard_object, Arel.sql('"rank" NULLS LAST, "user_id"')
      )
      verification_leaderboard = Arel::SelectManager.new
        .project(
          Arel.coalesce(
            Baw::Arel::Nodes::JsonAgg.new([ordered_leaderboard_object]),
            Arel.sql("'[]'::json")
          )
        )
        .from(leaderboard_rows_table)

      # TODO: move projections to projections
      Arel::SelectManager.new
        .project(
          Arel.star.count.as('verifications_count'),
          base_table[:audio_event_id].count(true).as('verified_events'),
          Arel.star.count.filter(base_table[:creator_id].eq(user_id)).as('user_verified_count'),
          base_table[:audio_event_id].count(true).filter(base_table[:creator_id].eq(user_id))
            .as('user_verified_events_count'),
          Arel.grouping(overrun_distribution).as('overrun_distribution'),
          Arel.grouping(verification_leaderboard).as('verification_leaderboard')
        )
        .with(base_cte, ranked_leaderboard_cte, leaderboard_rows_cte)
        .from(base_table)
    end
  end
end
