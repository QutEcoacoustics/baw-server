# frozen_string_literal: true

describe RegionsController, type: :routing do
  describe 'routing' do
    it { expect(get('provenances')).to route_to('provenances#index', format: 'json') }
    it { expect(post('provenances')).to route_to('provenances#create', format: 'json') }
    it { expect(get('provenances/new')).to route_to('provenances#new', format: 'json') }
    it { expect(put('provenances/1')).to route_to('provenances#update', format: 'json', id: '1') }
    it { expect(patch('provenances/1')).to route_to('provenances#update', format: 'json', id: '1') }
    it { expect(delete('provenances/1')).to route_to('provenances#destroy', format: 'json', id: '1') }

    it_behaves_like 'our api routing patterns', '/provenances', 'provenances', [:filterable]
  end
end
