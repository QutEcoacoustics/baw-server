# frozen_string_literal: true


# need request spec here so that actual body content is returned
describe 'Rack rewrite', type: :request do
  describe :routing do
    client_app_content = /Client application placeholder.*This is the page that will be rendered if a client side view needs to be rendered./m

    it do
      get('/listen')
      expect(response.body).to match(client_app_content)
    end

    it do
      get('/birdwalks')
      expect(response.body).to match(client_app_content)
    end

    it do
      get('/library')
      expect(response.body).to match(client_app_content)
    end

    it do
      get('/demo')
      expect(response.body).to match(client_app_content)
    end

    it do
      get('/visualize')
      expect(response.body).to match(client_app_content)
    end

    it do
      get('/audio_analysis')
      expect(response.body).to match(client_app_content)
    end

    it do
      get('/citsci')
      expect(response.body).to match(client_app_content)
    end
  end
end
