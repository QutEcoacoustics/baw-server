require 'rails_helper'

describe 'Rack rewrite', :type => :feature  do # :type => :routing
  describe :routing do

    client_app_content = 'Client application placeholder This is the page that will be rendered if a client side view needs to be rendered.'

    it {
      visit '/listen'
      expect(page.text).to include(client_app_content)
    }

    it {
      visit '/birdwalks'
      expect(page.text).to include(client_app_content)
    }

    it {
      visit '/library'
      expect(page.text).to include(client_app_content)
    }

    it {
      visit '/demo'
      expect(page.text).to include(client_app_content)
    }

    it {
      visit '/visualize'
      expect(page.text).to include(client_app_content)
    }

    it {
      visit '/audio_analysis'
      expect(page.text).to include(client_app_content)
    }

  end
end