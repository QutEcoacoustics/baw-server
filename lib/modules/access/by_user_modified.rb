module Access

  # Methods for retrieving models based on the users that created or updated them.
  class ByUserModified
    class << self

      # Get analysis jobs created or updated by user.
      # @param [User] user
      # @return [ActiveRecord::Relation]
      def analysis_jobs(user)
        user = Access::Validate.user(user, false)
        AnalysisJob
            .where('(analysis_jobs.creator_id = ? OR analysis_jobs.updater_id = ?)', user.id, user.id)
            .order('analysis_jobs.updated_at DESC')
      end

      # Get audio events created or updated by user.
      # @param [User] user
      # @return [ActiveRecord::Relation]
      def audio_events(user)
        user = Access::Validate.user(user, false)
        AudioEvent
            .where('(audio_events.creator_id = ? OR audio_events.updater_id = ?)', user.id, user.id)
            .order('audio_events.updated_at DESC')
      end

      # Get audio event comments created or updated by user.
      # @param [User] user
      # @return [ActiveRecord::Relation]
      def audio_event_comments(user)
        user = Access::Validate.user(user, false)
        AudioEventComment
            .where('(audio_event_comments.creator_id = ? OR audio_event_comments.updater_id = ?)', user.id, user.id)
            .order('audio_event_comments.updated_at DESC')
      end

      # Get bookmarks created or updated by user.
      # @param [User] user
      # @return [ActiveRecord::Relation]
      def bookmarks(user)
        user = Access::Validate.user(user, false)
        Bookmark
            .where('(bookmarks.creator_id = ? OR bookmarks.updater_id = ?)', user.id, user.id)
            .order('bookmarks.updated_at DESC')
      end

      # Get saved searches created or updated by user.
      # @param [User] user
      # @return [ActiveRecord::Relation]
      def saved_searches(user)
        user = Access::Validate.user(user, false)
        SavedSearch
            .where('(saved_searches.creator_id = ?)', user.id)
            .order('saved_searches.created_at DESC')
      end

      # Get taggings created or updated by user.
      # @param [User] user
      # @return [ActiveRecord::Relation]
      def taggings(user)
        user = Access::Validate.user(user, false)
        Tagging
            .where('(audio_events_tags.creator_id = ? OR audio_events_tags.updater_id = ?)', user.id, user.id)
            .order('audio_events_tags.updated_at DESC')
      end

    end
  end
end