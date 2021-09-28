# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Harvest
      module Metadata
        def self.filename
          Settings.actions.harvest.config_file_name
        end

        def self.generate_yaml(project_id, site_id, uploaders, recursive:, utc_offset: nil)
          raise ArgumentError, 'recursive must be `true` or `false`' unless [true, false].include?(recursive)

          uploader_section =
            if uploaders.blank?
              'uploader_id: '
            else
              Array(uploaders)
                .uniq(&:id)
                .map { |user|
                "#uploader_id: #{user.id} # #{user.user_name}"
              }.append(
              "uploader_id: #{Array(uploaders).last.id}"
            ).join("\n")
            end

          <<~YAML
            # this file should be named '#{filename}'
            # the project
            project_id: #{project_id}

            # the site
            site_id: #{site_id}

            # this needs to be set manually
            # below is a list of uploader_ids that have write access to this project
            # uncomment the one that you want to set as the uploader of the audio files
            # |---------- IMPORTANT: Ensure there is no whitespaces left before uploader_id
            #{uploader_section}

            #
            # this is the timezone for all the recordings.
            # the value should be the timezone offset that
            # the recorder was set to when it started recording.
            # example: `utc_offset: '+10'` for Brisbane, Australia
            utc_offset: '#{utc_offset.nil? ? 'INTENTIONALLY_INVALID' : utc_offset}'

            # recursive: if true apply the settings from this file to all
            # sub-directories.#{' '}
            recursive: #{recursive}

            # structured metadata to add to each recording.
            # use this to record information about sensors, etc...
            metadata:
            #  sensor_type: SM2
            #  notes:
            #    - stripped left channel due to bad mic
            #    - appears to have electronic interference from solar panel

          YAML
        end
      end
    end
  end
end
