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

  def self.stats_schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        count: { type: 'integer', readOnly: true },
        verified_event_count: { type: 'integer', readOnly: true },
        user_verified_count: { type: 'integer', readOnly: true },
        user_verified_events_count: { type: 'integer', readOnly: true },
        unique_verifiers_count: { type: 'integer', readOnly: true },
        overrun_distribution: {
          type: 'array',
          readOnly: true,
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              run: { type: 'integer' },
              count: { type: 'integer' },
              overflow: { type: 'string', enum: ['true'] }
            },
            required: [:run, :count]
          }
        },
        verification_leaderboard: {
          type: 'array',
          readOnly: true,
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              user_id: Api::Schema.id(nullable: true),
              verification_count: { type: 'integer' },
              rank: { type: ['integer', 'null'] }
            },
            required: [:user_id, :verification_count, :rank]
          }
        }
      },
      required: [
        :count,
        :verified_event_count,
        :user_verified_count,
        :user_verified_events_count,
        :unique_verifiers_count,
        :overrun_distribution,
        :verification_leaderboard
      ],
      readOnly: true
    }.freeze
  end

  # Stats hook consumed by Api::Stats#execute_stats via the controller.
  #
  # @param user [User, nil] the requesting user
  # @return [Proc] a callable that reshapes the filtered query for stats
  def self.stats_hook(user_id, base_table, query)
    base_cte = Arel::Nodes::As.new(base_table, query.arel)

    user_counts_subquery = user_counts_arel(table: base_table).as('user_counts')

    user_rank_cte = Arel::Nodes::As.new(
      users_ranked_table,
      users_ranked_arel(table: user_counts_subquery)
    )

    leaderboard_cte = Arel::Nodes::As.new(leaderboard_table, leaderboard_arel(user_id))

    Arel::SelectManager.new
      .with(base_cte, user_rank_cte, leaderboard_cte)
      .from(base_table)
  end

  # Per-user verification counts.
  # @param table [Arel::Table] the table containing verifications
  def self.user_counts_arel(table:)
    count = table[:id].count.as('verification_count')

    Arel::SelectManager.new
      .project(table[:creator_id].as('user_id'), count)
      .from(table)
      .group(table[:creator_id])
  end

  def self.users_ranked_table
    Arel::Table.new('user_rank')
  end

  # Returns the per-user verification counts and their rank, where 1 is the user
  # with the most verifications.
  # @param table [Arel::Table] the table containing user verification counts
  def self.users_ranked_arel(table:)
    Arel::SelectManager.new
      .project(
        table[:user_id],
        table[:verification_count],
        Arel.sql('RANK() OVER (ORDER BY verification_count DESC) AS rank')
      )
      .from(table)
  end

  # Returns the top 5 users by verification count.
  def self.top_users_arel
    users_ranked_table.project(Arel.star).where(users_ranked_table[:rank].lteq(5))
  end

  # Returns the requesting user's rank if they are not in the top 5.
  def self.user_rank_arel(user_id)
    users_ranked_table
      .project(Arel.star)
      .where(users_ranked_table[:user_id].eq(user_id).and(users_ranked_table[:rank].gt(5)))
  end

  # Return a null rank row if the requesting user has no verifications (or is anonymous).
  def self.absent_user_arel(user_id)
    request_user = Arel::SelectManager.new
      .project(Arel.sql('1'))
      .from(users_ranked_table)
      .where(users_ranked_table[:user_id].eq(user_id))

    Arel::SelectManager.new
      .project(Arel::Nodes.build_quoted(user_id), 0, Arel::Nodes.build_quoted(nil))
      .where(request_user.exists.not)
  end

  def self.leaderboard_table
    Arel::Table.new('leaderboard_table')
  end

  # Union the three subqueries to get the final leaderboard.
  def self.leaderboard_arel(user_id)
    Arel::Nodes::UnionAll.new(
      top_users_arel.union(:all, user_rank_arel(user_id)),
      absent_user_arel(user_id).ast
    )
  end

  # Return the leaderboard as a single JSON array, ordered by rank and user_id,
  # with null ranks last.
  def self.leaderboard_aggregation_arel
    leaderboard = Arel.json({
      user_id: leaderboard_table[:user_id],
      verification_count: leaderboard_table[:verification_count],
      rank: leaderboard_table[:rank]
    })

    ordered_leaderboard = Arel::Nodes::InfixOperation.new(
      'ORDER BY', leaderboard, Arel.sql('"rank" NULLS LAST, "user_id"')
    )

    Arel.grouping(
      Arel::SelectManager.new
        .project(
          Arel.coalesce(
            Baw::Arel::Nodes::JsonAgg.new([ordered_leaderboard]),
            Arel.sql("'[]'::json")
          )
        )
        .from(leaderboard_table)
    )
  end

  # Returns the distribution of taggings by verification run count. A run is a
  # verification by a distinct user; the final bucket contains five or more
  # runs.
  #
  # @param verifications_table [Arel::Table] the base table to use for the query
  def self.overrun_distribution_arel(verifications_table:)
    counts_by_tagging = verifications_table
      .project(
        verifications_table[:audio_event_id],
        verifications_table[:tag_id],
        verifications_table[:id].count
      )
      .group(verifications_table[:audio_event_id], verifications_table[:tag_id])

    subquery = counts_by_tagging.as('counts_by_tagging')

    Arel.grouping(
      Arel::SelectManager.new
        .project(
          Arel::Nodes::NamedFunction.new('json_build_array', [
            Arel.json({ run: 1, count: Arel.star.count.filter(subquery[:count].eq(1)) }),
            Arel.json({ run: 2, count: Arel.star.count.filter(subquery[:count].eq(2)) }),
            Arel.json({ run: 3, count: Arel.star.count.filter(subquery[:count].eq(3)) }),
            Arel.json({ run: 4, count: Arel.star.count.filter(subquery[:count].eq(4)) }),
            Arel.json({ run: 5, count: Arel.star.count.filter(subquery[:count].gteq(5)), overflow: 'true' })
          ])
        )
        .from(subquery)
    )
  end
end
