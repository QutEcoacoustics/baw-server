# frozen_string_literal: true

require 'rails_helper'

describe 'CMS' do
  create_standard_cms_pages

  # assets should always be available
  context 'allows users with no credentials to fetch assets' do
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
end
