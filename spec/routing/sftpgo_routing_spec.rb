# frozen_string_literal: true

describe Internal::SftpgoController, type: :routing do
  describe 'routing' do
    it { expect(post('/internal/sftpgo/hook')).to route_to('internal/sftpgo#hook', format: 'json') }
  end
end
