# frozen_string_literal: true

namespace :baw do
  namespace :camtrap_dp do
    profile = BawWorkers::Export::CamtrapDp::Profile

    desc 'Download the pinned camtrap-dp profile assets and build the local validation profile.'
    task :update do
      download_result = profile.download
      sections = profile.add_readme_section('Downloaded profile assets', download_result)
      puts sections.first, "\n"

      validation_result = profile.create_local_validation_profile
      sections = profile.add_readme_section('Created local validation profile', validation_result, sections: sections)
      puts sections.second, "\n"

      profile.write_readme(sections)
    end
  end
end
