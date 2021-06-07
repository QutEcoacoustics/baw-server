# frozen_string_literal: true



describe QuestionsController, type: :routing do
  describe :routing do
    it { expect(get('/questions')).to route_to('questions#index', format: 'json') }
    it { expect(get('studies/1/questions')).to route_to('questions#index', study_id: '1', format: 'json') }
    it { expect(get('/questions/1')).to route_to('questions#show', id: '1', format: 'json') }
    it { expect(get('/questions/new')).to route_to('questions#new', format: 'json') }
    it { expect(get('/questions/filter')).to route_to('questions#filter', format: 'json') }
    it { expect(post('/questions/filter')).to route_to('questions#filter', format: 'json') }
    it { expect(post('/questions')).to route_to('questions#create', format: 'json') }
    it { expect(put('/questions/1')).to route_to('questions#update', id: '1', format: 'json') }
    it { expect(delete('/questions/1')).to route_to('questions#destroy', id: '1', format: 'json') }
  end
end
