# frozen_string_literal: true

describe Provenance do
  subject { build(:provenance) }

  it { is_expected.to be_valid }

  it 'is invalid without a name' do
    subject.name = nil
    expect(subject).to be_invalid
  end

  it 'is invalid without a url' do
    subject.url = nil
    expect(subject).to be_valid
  end

  it 'is invalid with an invalid url' do
    subject.url = 'not a url'
    expect(subject).to be_invalid
  end

  it 'is invalid with a duplicate name but the same version' do
    subject.save!
    new_version = build(:provenance, name: subject.name, version: subject.version)
    expect(new_version).to be_invalid
  end

  it 'allows duplicate names for different versions' do
    subject.save!
    new_version = build(:provenance, name: subject.name, version: '1.1.1')
    expect(new_version).to be_valid
  end
end
