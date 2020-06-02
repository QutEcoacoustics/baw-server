require 'rails_helper'

describe StudiesController, :type => :routing do
  describe :routing do

    it { expect(get('/studies')).to route_to('studies#index', format: 'json') }
    it { expect(get('/studies/1')).to route_to('studies#show', id: '1', format: 'json') }
    it { expect(get('/studies/new')).to route_to('studies#new', format: 'json') }
    it { expect(get('/studies/filter')).to route_to('studies#filter', format: 'json') }
    it { expect(post('/studies/filter')).to route_to('studies#filter', format: 'json') }
    it { expect(post('/studies')).to route_to('studies#create', format: 'json') }
    it { expect(put('/studies/1')).to route_to('studies#update', id: '1', format: 'json') }
    it { expect(delete('/studies/1')).to route_to('studies#destroy', id: '1', format: 'json') }

  end
end