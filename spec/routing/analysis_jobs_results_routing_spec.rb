# frozen_string_literal: true

describe AnalysisJobsResultsController, type: :routing do
  describe :routing do
    it do
      expect(get('/analysis_jobs/123/results')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          format: 'json')
    end

    it do
      expect(get('/analysis_jobs/123/results/')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          format: 'json')
    end

    it do
      expect(get('/analysis_jobs/123/results/3')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          results_path: '3',
          format: 'json')
    end

    it do
      expect(get('/analysis_jobs/123/results/3/')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          results_path: '3',
          format: 'json')
    end

    it do
      # This one is a little weird - we could have a result folder named edit.
      # Support any name rather than block listing names.
      expect(get('/analysis_jobs/123/results/3/edit')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          results_path: '3/edit',
          format: 'json')
    end

    it do
      expect(get('analysis_jobs/123/results/187684/test/test')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          results_path: '187684/test/test',
          format: 'json')
    end

    it {
      expect(get('analysis_jobs/123/results/187684/test/test/file.csv')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: '123',
          results_path: '187684/test/test/file.csv',
          format: 'json')
    }
  end

  describe :system_routing do
    it do
      expect(get('/analysis_jobs/system/results')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          format: 'json')
    end

    it do
      expect(get('/analysis_jobs/system/results/')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          format: 'json')
    end

    it do
      expect(get('/analysis_jobs/system/results/3')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          results_path: '3',
          format: 'json')
    end

    it do
      expect(get('/analysis_jobs/system/results/3/')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          results_path: '3',
          format: 'json')
    end

    it do
      # This one is a little weird - we could have a result folder named edit.
      # Support any name rather than blacklisting names.
      expect(get('/analysis_jobs/system/results/3/edit')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          results_path: '3/edit',
          format: 'json')
    end

    it do
      expect(get('analysis_jobs/system/results/187684/test/test')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          results_path: '187684/test/test',
          format: 'json')
    end

    it {
      expect(get('analysis_jobs/system/results/187684/test/test/file.csv')).to \
        route_to('analysis_jobs_results#results',
          analysis_job_id: 'system',
          results_path: '187684/test/test/file.csv',
          format: 'json')
    }
  end
end
