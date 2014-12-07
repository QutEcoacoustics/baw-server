require 'spec_helper'

describe PublicController, :type => :routing do
  describe :routing do

    it { expect(get('/')).to route_to('public#index') }
    it { expect(get('/status')).to route_to('public#status', format: 'json') }
    it { expect(get('/website_status')).to route_to('public#website_status') }

    #it { expect(get('/job_queue_status')).to route_to('Resque::Server') }
    #it { expect(get('/doc')).to route_to('Raddocs::App') }

    it { expect(get('/does_not_exist')).to route_to('errors#route_error', requested_route: 'does_not_exist') }

    it { expect(get('/contact_us')).to route_to('public#new_contact_us') }
    it { expect(post('/contact_us')).to route_to('public#create_contact_us') }

    it { expect(get('/bug_report')).to route_to('public#new_bug_report') }
    it { expect(post('/bug_report')).to route_to('public#create_bug_report') }

    it { expect(get('/data_request')).to route_to('public#new_data_request') }
    it { expect(post('/data_request')).to route_to('public#create_data_request') }

    it { expect(get('/credits')).to route_to('public#credits') }
    it { expect(get('/ethics_statement')).to route_to('public#ethics_statement') }
    it { expect(get('/disclaimers')).to route_to('public#disclaimers') }

  end
end