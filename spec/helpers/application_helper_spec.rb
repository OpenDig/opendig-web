require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#oauth_start_url' do
    it 'starts the handshake on the apex domain, carrying the current host as origin' do
      request.host = 'balua.opendig.org'

      url = helper.oauth_start_url('google_oauth2')

      expect(url).to start_with('http://opendig.org/auth/google_oauth2?origin=')
      expect(url).to include(CGI.escape('http://balua.opendig.org/'))
    end

    it 'preserves a non-default port (dev) and the registrable domain' do
      request.host = 'balua.lvh.me'
      request.env['HTTP_HOST'] = 'balua.lvh.me:3000'

      expect(helper.oauth_start_url('developer')).to start_with('http://lvh.me:3000/auth/developer?origin=')
    end
  end
end
