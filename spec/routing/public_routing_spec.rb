require 'spec_helper'

describe PublicController do
  describe :routing do

    it { expect(get('/')).to route_to('public#index') }
    it { expect(get('/status')).to route_to('public#status', format: 'json') }
    it { expect(get('/website_status')).to route_to('public#website_status') }

    #it { expect(get('/job_queue_status')).to route_to('Resque::Server') }
    #it { expect(get('/doc')).to route_to('Raddocs::App') }

    it { expect(get('/does_not_exist')).to route_to('errors#routing', requested_route: 'does_not_exist')}

  end
end