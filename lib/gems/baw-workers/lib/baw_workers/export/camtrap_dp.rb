# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      DATAPACKAGE_FILENAME = Pathname.new('datapackage.json')
      OBSERVATIONS_FILENAME = Pathname.new('observations.csv')
      DEPLOYMENTS_FILENAME = Pathname.new('deployments.csv')
      MEDIA_FILENAME = Pathname.new('media.csv')

      PACKAGE_PATH = Pathname.new('dp')
      ZIP_PATH = PACKAGE_PATH.sub_ext('.zip')

      PACKAGE_FILENAMES = {
        deployments: DEPLOYMENTS_FILENAME,
        media: MEDIA_FILENAME,
        observations: OBSERVATIONS_FILENAME,
        datapackage: DATAPACKAGE_FILENAME
      }
    end
  end
end
