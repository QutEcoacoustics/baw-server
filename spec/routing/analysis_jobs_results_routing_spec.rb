require 'rails_helper'

describe AnalysisJobsResultsController, :type => :routing do

  describe :routing do

    it {
      expect(get('/analysis_jobs/123/audio_recordings/3/results')).to \
        route_to('analysis_jobs_results#show',
                 analysis_job_id: '123',
                 audio_recording_id: '3',
                 format: 'json')
    }
    it {
      expect(get('/analysis_jobs/123/audio_recordings/3/results/')).to \
        route_to('analysis_jobs_results#show',
                 analysis_job_id: '123',
                 audio_recording_id: '3',
                 format: 'json')
    }

    it {
      # This one is a little weird - we could have a result folder named edit.
      # Support any name rather than blacklisting names.
      expect(get('/analysis_jobs/123/audio_recordings/3/results/edit')).to \
      route_to('analysis_jobs_results#show',
               analysis_job_id: '123',
               audio_recording_id: '3',
               results_path: 'edit',
               format: 'json')
    }

    it {
      expect(get('analysis_jobs/123/audio_recordings/187684/results/test/test')).to \
       route_to('analysis_jobs_results#show',
                analysis_job_id: '123',
                audio_recording_id: '187684',
                results_path: 'test/test',
                format: 'json')
    }

    it {
      expect(get('analysis_jobs/123/audio_recordings/187684/results/test/test/file.csv')).to \
       route_to('analysis_jobs_results#show',
                analysis_job_id: '123',
                audio_recording_id: '187684',
                results_path: 'test/test/file.csv',
                format: 'json')
    }

  end

  describe :system_routing do

    it {
      expect(get('/analysis_jobs/system/audio_recordings/3/results')).to \
        route_to('analysis_jobs_results#show',
                 analysis_job_id: 'system',
                 audio_recording_id: '3',
                 format: 'json')
    }
    it {
      expect(get('/analysis_jobs/system/audio_recordings/3/results/')).to \
        route_to('analysis_jobs_results#show',
                 analysis_job_id: 'system',
                 audio_recording_id: '3',
                 format: 'json')
    }

    it {
      # This one is a little weird - we could have a result folder named edit.
      # Support any name rather than blacklisting names.
      expect(get('/analysis_jobs/system/audio_recordings/3/results/edit')).to \
      route_to('analysis_jobs_results#show',
               analysis_job_id: 'system',
               audio_recording_id: '3',
               results_path: 'edit',
               format: 'json')
    }

    it {
      expect(get('analysis_jobs/system/audio_recordings/187684/results/test/test')).to \
        route_to('analysis_jobs_results#show',
                 analysis_job_id: 'system',
                 audio_recording_id: '187684',
                 results_path: 'test/test',
                 format: 'json')
    }

    it {
      expect(get('analysis_jobs/system/audio_recordings/187684/results/test/test/file.csv')).to \
        route_to('analysis_jobs_results#show',
                 analysis_job_id: 'system',
                 audio_recording_id: '187684',
                 results_path: 'test/test/file.csv',
                 format: 'json')
    }

  end
end