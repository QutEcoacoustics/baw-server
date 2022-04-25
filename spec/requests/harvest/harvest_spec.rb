# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting a batch of files' do
  include HarvestSpecCommon

  it 'will not allow a harvest to be created if the project does not allow uploads' do
    project.allow_audio_upload = false
    project.save!

    create_harvest

    expect_error(
      :unprocessable_entity,
      'Record could not be saved',
      { project: ['A harvest cannot be created unless its parent project has enabled audio upload'] }
    )
  end
end
