require 'rails_helper'

describe AnalysisJobsItemsController, :type => :routing do
  def make_expected(action, audio_recording_id = nil, analysis_job_id = 123)
    route_to(
        'analysis_jobs_items#' + action,
        audio_recording_id: audio_recording_id,
        analysis_job_id: analysis_job_id,
        format: 'json'
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
      expect(post('/analysis_jobs/123/audio_recordings')).not_to be_routable
    }
    it {
      expect(get('/analysis_jobs/123/audio_recordings/new')).not_to be_routable
    }
    it {
      expect(get('/analysis_jobs/123/audio_recordings/3/edit')).not_to be_routable
    }
    it {
      expect(put('/analysis_jobs/123/audio_recordings/3')).to make_expected('update', '3')
    }
    it {
      expect(patch('/analysis_jobs/123/audio_recordings/3')).to make_expected('update', '3')
    }
    it {
      expect(delete('/analysis_jobs/123/audio_recordings/3')).not_to be_routable
    }

    it {
      expect(get('/analysis_jobs/123/audio_recordings/filter')).to make_expected('filter')
    }

  end

  describe :system_routing do

    it {
      expect(get('/analysis_jobs/system/audio_recordings/3')).to make_expected('system_show', '3', 'system')
    }
    it {
      expect(get('/analysis_jobs/system/audio_recordings')).to make_expected('system_index', nil, 'system')
    }

    it {
      expect(post('/analysis_jobs/system/audio_recordings')).not_to be_routable
    }
    it {
      expect(get('/analysis_jobs/system/audio_recordings/new')).not_to be_routable
    }
    it {
      expect(get('/analysis_jobs/system/audio_recordings/3/edit')).not_to be_routable
    }
    it {
      expect(put('/analysis_jobs/system/audio_recordings/3')).to make_expected('system_update', '3', 'system')
    }
    it {
      expect(patch('/analysis_jobs/system/audio_recordings/3')).to make_expected('system_update', '3', 'system')
    }
    it {
      expect(delete('/analysis_jobs/system/audio_recordings/3')).not_to be_routable
    }

    it {
      expect(get('/analysis_jobs/system/audio_recordings/filter')).to make_expected('system_filter', nil, 'system')
    }

  end

  describe :results_routing  do

    it {
      expect(
          get('analysis_jobs/system/audio_recordings/187684/test/test')
      ).to route_to('analysis_jobs_items#system_show', analysis_job_id: 'system', audio_recording_id: '187684', results_path: 'test/test', format: 'json') }

    it {
      expect(
          get('analysis_jobs/123/audio_recordings/187684/test/test')
      ).to route_to('analysis_jobs_items#show', analysis_job_id: '123', audio_recording_id: '187684', results_path: 'test/test', format: 'json') }



  end

end