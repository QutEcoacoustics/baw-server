# frozen_string_literal: true

describe 'CMS' do
  create_standard_cms_pages
  prepare_users

  # assets should always be available
context 'when users have no credentials, they can fetch assets' do
    let(:page) {
      Comfy::Cms::Page.where(slug: 'index').first
    }

    example 'javascript' do
      tag = ComfortableMexicanSofa::Content::Tag::Asset.new(
        context: page,
        params: ['default', { 'type' => 'js' }]
      )
      url = tag.content
      expect(url).to end_with('.js')

      get url

      expect_success
      expect(response.content_type).to eq('application/javascript; charset=utf-8')
    end

    example 'css' do
      tag = ComfortableMexicanSofa::Content::Tag::Asset.new(
        context: page,
        params: ['default', { 'type' => 'css' }]
      )
      url = tag.content
      expect(url).to end_with('.css')

      get url

      expect_success
      expect(response.content_type).to eq('text/css; charset=utf-8')
    end
  end

  context 'when a user is an admin they can access the backend' do
    example 'access admin/cms' do
      get '/admin/cms', headers: api_request_headers(admin_token)

      expect(response).to have_http_status(:found)
    end
  end
end
