require 'rails_helper'

describe AnalysisJobsItemsController, :type => :routing do
  def make_expected(action, audio_recording_id = nil, analysis_job_id = '123')
    params ={analysis_job_id: analysis_job_id, format: 'json'}
    params[:audio_recording_id] = audio_recording_id if audio_recording_id != nil

    route_to(
        'analysis_jobs_items#' + action,
        params
    )
  end

  describe :routing do

    it {
      expect(get('/analysis_jobs/123/audio_recordings/3')).to make_expected('show', '3')
    }
    it {
      expect(get('/analysis_jobs/123/audio_recordings')).to make_expected('index')
    }

    it {
      expect(post('/analysis_jobs/123/audio_recordings')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/audio_recordings')
    }
    it {
      # technically this *route* should work, but the action should fail
      expect(get('/analysis_jobs/123/audio_recordings/new')).to make_expected('show', 'new')
    }
    it {
      expect(get('/analysis_jobs/123/audio_recordings/3/edit')).to \
      route_to('errors#route_error', requested_route: 'analysis_jobs/123/audio_recordings/3/edit')
    }
    it {
      expect(put('/analysis_jobs/123/audio_recordings/3')).to make_expected('update', '3')
    }
    it {
      expect(patch('/analysis_jobs/123/audio_recordings/3')).to make_expected('update', '3')
    }
    it {
      expect(delete('/analysis_jobs/123/audio_recordings/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/audio_recordings/3')
    }

    it {
      expect(get('/analysis_jobs/123/audio_recordings/filter')).to make_expected('filter')
    }

  end

  describe :system_routing do

    it {
      expect(get('/analysis_jobs/system/audio_recordings/3')).to make_expected('show', '3', 'system')
    }
    it {
      expect(get('/analysis_jobs/system/audio_recordings')).to make_expected('index', nil, 'system')
    }

    it {
      expect(post('/analysis_jobs/system/audio_recordings')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/audio_recordings')
    }
    it {
      # technically this *route* should work, but the action should fail
      expect(get('/analysis_jobs/system/audio_recordings/new')).to make_expected('show', 'new', 'system')
    }
    it {
      expect(get('/analysis_jobs/system/audio_recordings/3/edit')).to \
      route_to('errors#route_error', requested_route: 'analysis_jobs/system/audio_recordings/3/edit')
    }
    it {
      expect(put('/analysis_jobs/system/audio_recordings/3')).to make_expected('update', '3', 'system')
    }
    it {
      expect(patch('/analysis_jobs/system/audio_recordings/3')).to make_expected('update', '3', 'system')
    }
    it {
      expect(delete('/analysis_jobs/system/audio_recordings/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/audio_recordings/3')
    }

    it {
      expect(get('/analysis_jobs/system/audio_recordings/filter')).to make_expected('filter', nil, 'system')
    }

  end

end