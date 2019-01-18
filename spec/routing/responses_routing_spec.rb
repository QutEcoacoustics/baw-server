require 'rails_helper'

describe ResponsesController, :type => :routing do
  describe :routing do

    it { expect(get('/responses')).to route_to('responses#index', format: 'json') }
    it { expect(get('studies/1/responses')).to route_to('responses#index', study_id: '1', format: 'json') }
    it { expect(get('/responses/1')).to route_to('responses#show', id: '1', format: 'json') }
    it { expect(get('/responses/new')).to route_to('responses#new', format: 'json') }
    it { expect(get('/responses/filter')).to route_to('responses#filter', format: 'json') }
    it { expect(post('/responses/filter')).to route_to('responses#filter', format: 'json') }
    it { expect(post('/responses')).to route_to('responses#create', format: 'json') }
    it { expect(put('/responses/1')).to route_to('errors#route_error', requested_route: 'responses/1') }
    it { expect(delete('/responses/1')).to route_to('responses#destroy', id: '1', format: 'json') }

  end
end