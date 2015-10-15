module Access
  # Queries to get models user has created or modified.
  class User
    class << self

      def projects(user)
        Access::Model.projects(user)
      end

      def sites(user)
        Access::Model.sites(user)
      end

      def bookmarks(user)
        user = Access::Core.validate_user(user)
        Bookmark
            .where('(bookmarks.creator_id = ? OR bookmarks.updater_id = ?)', user.id, user.id)
            .order('bookmarks.updated_at DESC')
      end

      def audio_events(user)
        user = Access::Core.validate_user(user)
        AudioEvent
            .where('(audio_events.creator_id = ? OR audio_events.updater_id = ?)', user.id, user.id)
            .order('audio_events.updated_at DESC')
      end

      def audio_events_tags(user)
        user = Access::Core.validate_user(user)
        Tagging
            .where('(audio_events_tags.creator_id = ? OR audio_events_tags.updater_id = ?)', user.id, user.id)
            .order('audio_events_tags.updated_at DESC')
      end

      def audio_event_comments(user)
        user = Access::Core.validate_user(user)
        AudioEventComment
            .where('(audio_event_comments.creator_id = ? OR audio_event_comments.updater_id = ?)', user.id, user.id)
            .order('audio_event_comments.updated_at DESC')
      end

      def saved_searches(user)
        user = Access::Core.validate_user(user)
        SavedSearch
            .where('(saved_searches.creator_id = ?)', user.id)
            .order('saved_searches.created_at DESC')
      end

      def analysis_jobs(user)
        user = Access::Core.validate_user(user)
        AnalysisJob
            .where('(analysis_jobs.creator_id = ? OR analysis_jobs.updater_id = ?)', user.id, user.id)
            .order('analysis_jobs.updated_at DESC')
      end

    end
  end
end