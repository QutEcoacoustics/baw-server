# frozen_string_literal: true

namespace :baw do
  namespace :camtrap_dp do
    Profile = BawWorkers::Export::CamtrapDp::Profile
    log_path = File.join(Profile::DIRECTORY, 'profile_update.log')

    directory Profile::DIRECTORY

    desc 'Download pinned camtrap-dp profile assets unconditionally.'
    task download: [Profile::DIRECTORY] do
      logger = Logger.new(log_path)
      result = Profile.download

      puts 'Downloaded profile assets:'
      pp result

      logger.info("Downloaded profile assets:\n#{result.pretty_inspect}")
    end

    file Profile::LOCAL_VALIDATION_PROFILE_PATH => [Profile::PROFILE_PATH] do
      logger = Logger.new(log_path)
      result = Profile.create_local_validation_profile

      puts 'Created local validation profile:'
      pp result

      logger.info("Created local validation profile:\n#{result.pretty_inspect}")
    end

    desc 'Refresh the local offline validation profile if the source profile changed.'
    task refresh_profile: Profile::LOCAL_VALIDATION_PROFILE_PATH

    desc 'Force update: run the download and refresh_profile tasks.'
    task update: [:download, :refresh_profile]
  end
end
