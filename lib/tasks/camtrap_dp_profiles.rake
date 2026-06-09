# frozen_string_literal: true

namespace :baw do
  namespace :camtrap_dp do
    namespace :profiles do
      desc 'Inline external camtrap profile $refs into a local offline validation profile.'
      task :refresh, [:profile_url] => :environment do |_task, args|
        profile_url = args[:profile_url].presence || ENV.fetch('CAMTRAP_DP_PROFILE_URL', nil)

        if profile_url.present?
          downloaded = BawWorkers::Export::CamtrapDp::Datapackage.download_profile!(profile_url)
          puts "Downloaded profile to #{downloaded}"
        end

        result = BawWorkers::Export::CamtrapDp::Datapackage.refresh_local_profile!

        puts "Wrote local validation profile: #{result.fetch(:profile_path)}"
        puts "External reference documents loaded: #{result.fetch(:downloaded_ref_count)}"
      end
    end
  end
end
