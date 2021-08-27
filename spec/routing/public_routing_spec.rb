# frozen_string_literal: true

describe PublicController, type: :routing do
  describe :routing do
    it { expect(get('/')).to route_to('public#index') }
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
    it { expect(get('/data_upload')).to route_to('public#data_upload') }
    it { expect(get('/disclaimers')).to route_to('public#disclaimers') }

    # CORS tests (invalid, as they do not have correct headers)
    it {
      expect(options: '/projects').to route_to(controller: 'public', action: 'cors_preflight',
        requested_route: 'projects')
    }

    it {
      expect(options: '/sites').to route_to(controller: 'public', action: 'cors_preflight', requested_route: 'sites')
    }

    it {
      expect(options: '/blah_blah').to route_to(controller: 'public', action: 'cors_preflight',
        requested_route: 'blah_blah')
    }

    it {
      expect(options: '/projects/1/sites/2/audio_recordings/3').to route_to(controller: 'public', action: 'cors_preflight',
        requested_route: 'projects/1/sites/2/audio_recordings/3')
    }
  end
end
