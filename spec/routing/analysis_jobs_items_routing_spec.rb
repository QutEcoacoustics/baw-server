# frozen_string_literal: true

require 'rails_helper'

describe AnalysisJobsItemsController, type: :routing do
  def make_expected(action, audio_recording_id = nil, analysis_job_id = '123')
    params = { analysis_job_id: analysis_job_id, format: 'json' }
    params[:audio_recording_id] = audio_recording_id unless audio_recording_id.nil?

    route_to(
      'analysis_jobs_items#' + action,
      params
    )
  end

  describe :routing do
    it do
      expect(get('/analysis_jobs/123/audio_recordings/3')).to make_expected('show', '3')
    end
    it do
      expect(get('/analysis_jobs/123/audio_recordings')).to make_expected('index')
    end

    it do
      expect(post('/analysis_jobs/123/audio_recordings')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/audio_recordings')
    end
    it do
      # technically this *route* should work, but the action should fail
      expect(get('/analysis_jobs/123/audio_recordings/new')).to make_expected('show', 'new')
    end
    it do
      expect(get('/analysis_jobs/123/audio_recordings/3/edit')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/audio_recordings/3/edit')
    end
    it do
      expect(put('/analysis_jobs/123/audio_recordings/3')).to make_expected('update', '3')
    end
    it do
      expect(patch('/analysis_jobs/123/audio_recordings/3')).to make_expected('update', '3')
    end
    it do
      expect(delete('/analysis_jobs/123/audio_recordings/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/audio_recordings/3')
    end

    it {
      expect(get('/analysis_jobs/123/audio_recordings/filter')).to make_expected('filter')
    }
  end

  describe :system_routing do
    it do
      expect(get('/analysis_jobs/system/audio_recordings/3')).to make_expected('show', '3', 'system')
    end
    it do
      expect(get('/analysis_jobs/system/audio_recordings')).to make_expected('index', nil, 'system')
    end

    it do
      expect(post('/analysis_jobs/system/audio_recordings')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/audio_recordings')
    end
    it do
      # technically this *route* should work, but the action should fail
      expect(get('/analysis_jobs/system/audio_recordings/new')).to make_expected('show', 'new', 'system')
    end
    it do
      expect(get('/analysis_jobs/system/audio_recordings/3/edit')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/audio_recordings/3/edit')
    end
    it do
      expect(put('/analysis_jobs/system/audio_recordings/3')).to make_expected('update', '3', 'system')
    end
    it do
      expect(patch('/analysis_jobs/system/audio_recordings/3')).to make_expected('update', '3', 'system')
    end
    it do
      expect(delete('/analysis_jobs/system/audio_recordings/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/audio_recordings/3')
    end

    it {
      expect(get('/analysis_jobs/system/audio_recordings/filter')).to make_expected('filter', nil, 'system')
    }
  end
end
