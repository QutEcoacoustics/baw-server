require 'spec_helper'

describe PublicController do
  describe 'routing' do

    it 'routes to #index' do
      get('/').should route_to('public#index')
    end

    it 'routes to #status' do
      get('/status').should route_to('public#status')
    end

  end
end
