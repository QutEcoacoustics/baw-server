# frozen_string_literal: true

namespace :baw do
  namespace :camtrap_dp do
    profile = BawWorkers::Export::CamtrapDp::Profile

    desc 'Download the pinned camtrap-dp profile assets and build the local validation profile.'
    task :update do
      download_result = profile.download
      validation_result = profile.create_local_validation_profile
      readme = profile.build_readme(download_result, validation_result)

      print readme
      profile.write_readme(readme)
    end
  end
end
