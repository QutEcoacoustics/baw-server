# frozen_string_literal: true

require 'rails_helper'

describe CmsHelpers, type: :helper do
  it 'returns the site name' do
    result = helper.site_name
    expect(result).to eq(Settings.organisation_names.site_long_name)
  end
  it 'returns the parent site name' do
    result = helper.parent_site_name
    expect(result).to eq(Settings.organisation_names.parent_site_name)
  end
  it 'returns the site organisation name' do
    result = helper.organisation_name
    expect(result).to eq(Settings.organisation_names.organisation_name)
  end
  it 'returns the address (when logged in)' do
    allow(controller).to receive(:current_user).and_return(User.first)
    result = helper.address
    expect(result).to eq(Settings.organisation_names.address)
  end
  it 'address returns an empty string (when not logged in)' do
    allow(controller).to receive(:current_user).and_return(nil)
    result = helper.address
    expect(result).to eq('')
  end
  it 'address can return a custom string (when not logged in)' do
    allow(controller).to receive(:current_user).and_return(nil)
    result = helper.address('log in to see address')
    expect(result).to eq('log in to see address')
  end
  it 'address tells us when an address is not configured in settings' do
    allow(controller).to receive(:current_user).and_return(User.first)
    allow(Settings.organisation_names).to receive(:address).and_return(nil)
    result = helper.address
    expect(result).to eq('<address not configured>')
  end
end
