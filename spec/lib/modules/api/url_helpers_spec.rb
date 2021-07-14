# frozen_string_literal: true



describe Api::UrlHelpers do
  describe :url_helpers do
    create_entire_hierarchy

    it do
      expect(Api::UrlHelpers.make_listen_path).to eq('/listen')
    end

    it do
      actual = Api::UrlHelpers.make_listen_path(audio_recording, 120, 180)
      expect(actual).to eq("/listen/#{audio_recording.id}?start=120&end=180")
    end

    it do
      actual = Api::UrlHelpers.make_listen_path(audio_event, 120, 180)
      expect(actual).to eq("/listen/#{audio_event.audio_recording_id}?start=120&end=180")
    end

    it do
      actual = Api::UrlHelpers.make_listen_path(bookmark, 120, 180)
      expect(actual).to eq("/listen/#{bookmark.audio_recording_id}?start=120&end=180")
    end

    it do
      expect(Api::UrlHelpers.make_birdwalks_path).to eq('/birdwalks')
    end

    it do
      expect(Api::UrlHelpers.make_library_path).to eq('/library')
    end

    it do
      actual = Api::UrlHelpers.make_library_path(audio_recording, audio_event)
      expect(actual).to eq("/library/#{audio_recording.id}/audio_events/#{audio_event.id}")
    end

    it do
      actual = Api::UrlHelpers.make_library_path(audio_event)
      expect(actual).to eq("/library/#{audio_recording.id}/audio_events/#{audio_event.id}")
    end

    it do
      expect(Api::UrlHelpers.make_demo_path).to eq('/demo')
    end

    it do
      expect {
        Api::UrlHelpers.make_visualise_path
      }.to raise_error(ArgumentError)
    end

    it do
      actual = Api::UrlHelpers.make_visualise_path(project)
      expect(actual).to eq("/visualize?projectId=#{project.id}")
    end

    it do
      actual = Api::UrlHelpers.make_visualise_path(site)
      expect(actual).to eq("/visualize?siteId=#{site.id}")
    end

    context 'two sites' do
      let!(:site_2) { Creation::Common.create_site(owner_user, project) }

      it {
        actual = Api::UrlHelpers.make_visualise_path([site, site_2])
        expect(actual).to eq("/visualize?siteIds=#{site.id},#{site_2.id}")
      }
    end

    it do
      expect(Api::UrlHelpers.make_audio_analysis_path).to eq('/audio_analysis')
    end

    it {
      actual = Api::UrlHelpers.make_audio_analysis_path(analysis_job)
      expect(actual).to eq("/audio_analysis/#{analysis_job.id}")
    }
  end
end
