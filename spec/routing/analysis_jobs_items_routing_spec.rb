# frozen_string_literal: true

describe AnalysisJobsItemsController do
  def make_expected(action, analysis_job_item_id = nil, analysis_job_id = '123')
    params = { analysis_job_id:, format: 'json' }
    params[:id] = analysis_job_item_id unless analysis_job_item_id.nil?

    route_to(
      "analysis_jobs_items##{action}",
      params
    )
  end

  describe 'routing' do
    it do
      expect(get('/analysis_jobs/123/items/3')).to make_expected('show', '3')
    end

    it do
      expect(get('/analysis_jobs/123/items')).to make_expected('index')
    end

    it do
      expect(post('/analysis_jobs/123/items')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/items')
    end

    it do
      # technically this *route* should work, but the action should fail
      expect(get('/analysis_jobs/123/items/new')).to make_expected('show', 'new')
    end

    it do
      expect(get('/analysis_jobs/123/items/3/edit')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/items/3/edit')
    end

    it do
      expect(put('/analysis_jobs/123/items/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/items/3')
    end

    it do
      expect(patch('/analysis_jobs/123/items/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/items/3')
    end

    it do
      expect(delete('/analysis_jobs/123/items/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/123/items/3')
    end

    it_behaves_like 'our api routing patterns', '/analysis_jobs/123/items', 'analysis_jobs_items', [:filterable, :invocable],
      { analysis_job_id: '123' }, 'finish'
  end

  describe 'SYSTEM routing' do
    it do
      expect(get('/analysis_jobs/system/items/3')).to make_expected('show', '3', 'system')
    end

    it do
      expect(get('/analysis_jobs/system/items')).to make_expected('index', nil, 'system')
    end

    it do
      expect(post('/analysis_jobs/system/items')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/items')
    end

    it do
      # technically this *route* should work, but the action should fail
      expect(get('/analysis_jobs/system/items/new')).to make_expected('show', 'new', 'system')
    end

    it do
      expect(get('/analysis_jobs/system/items/3/edit')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/items/3/edit')
    end

    it do
      expect(put('/analysis_jobs/system/items/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/items/3')
    end

    it do
      expect(patch('/analysis_jobs/system/items/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/items/3')
    end

    it do
      expect(delete('/analysis_jobs/system/items/3')).to \
        route_to('errors#route_error', requested_route: 'analysis_jobs/system/items/3')
    end

    it {
      expect(get('/analysis_jobs/system/items/filter')).to make_expected('filter', nil, 'system')
    }
  end
end
