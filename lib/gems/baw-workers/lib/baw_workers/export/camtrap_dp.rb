# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      DATAPACKAGE_FILENAME = 'datapackage.json'
      OBSERVATIONS_FILENAME = 'observations.csv'
      DEPLOYMENTS_FILENAME = 'deployments.csv'
      MEDIA_FILENAME = 'media.csv'

      PACKAGE_PATH = 'dp'
      ZIP_PATH = 'dp.zip'

      PACKAGE_FILENAMES = {
        deployments: DEPLOYMENTS_FILENAME,
        media: MEDIA_FILENAME,
        observations: OBSERVATIONS_FILENAME,
        datapackage: DATAPACKAGE_FILENAME
      }
    end
  end
end
