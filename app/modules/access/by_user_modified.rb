# frozen_string_literal: true

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

      # Get audio event imports created or updated by user.
      # @param [User] user
      # @param include_admin [Boolean] if true will strictly only fetch records owned by user, and will not work for admin users
      # @return [::ActiveRecord::Relation]
      def audio_event_imports(user, include_admin: true)
        user = Access::Validate.user(user, true)

        return AudioEventImport.none if user.nil?

        return AudioEventImport.all if include_admin && Access::Core.is_admin?(user)

        AudioEventImport
          .where('(audio_event_imports.creator_id = ? OR audio_event_imports.updater_id = ?)', user.id, user.id)
          .order('audio_event_imports.updated_at DESC')
      end

      def audio_event_import_files(audio_event_import, user)
        user = Access::Validate.user(user, true)

        return AudioEventImportFile.none if user.nil?

        base_query = AudioEventImportFile
          .joins(:audio_event_import)
          .where(audio_event_import:)
          .order('audio_event_import_files.created_at DESC')

        return base_query if Access::Core.is_admin?(user)

        base_query
          .where('(audio_event_imports.creator_id = ?)', user.id)
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
