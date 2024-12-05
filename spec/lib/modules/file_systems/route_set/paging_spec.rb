# frozen_string_literal: true

require_relative 'route_set_context'
require_relative 'paging_shared_examples'

describe 'RouteSet' do
  include_context 'with route set context'

  describe 'paging a complex route set' do
    let(:analysis_job) { AnalysisJob.find(analysis_job_id) }
    let(:route_set) {
      FileSystems::RouteSet.new(
        root: FileSystems::Root.new(
          base_route_path,
          AnalysisJobsItem.where(analysis_job_id:)
        ),
        virtual: FileSystems::Virtual.new(
          FileSystems::Virtual::Directory.new(
            Project,
            :name,
            base_query_joins: { audio_recording: [site: [region: [:project]]] }
          ),
          # testing if i can omit joins for all lower layers since
          # the join is already defined at the top layer
          FileSystems::Virtual::Directory.new(Region, :name),
          FileSystems::Virtual::Directory.new(Site, :name),
          FileSystems::Virtual::Directory.new(AudioRecording,
            FileSystems::Virtual::NamePath.new(
              name: AudioRecording::ArelExpressions::BY_YEAR_AREL,
              path: AudioRecording::ArelExpressions::BY_YEAR_AREL,
              coerce: FileSystems::Virtual::TO_S
            )),
          FileSystems::Virtual::Directory.new(AudioRecording,
            FileSystems::Virtual::NamePath.new(
              name: AudioRecording::ArelExpressions::BY_MONTH_AREL,
              path: AudioRecording::ArelExpressions::BY_MONTH_AREL,
              coerce: FileSystems::Virtual::TO_S
            )),
          FileSystems::Virtual::Directory.new(
            AudioRecording,
            FileSystems::Virtual::NamePath.new(
              name: AudioRecording::FRIENDLY_NAME_AREL,
              path: AudioRecording.arel_table[:id]
            )
          ),
          FileSystems::Virtual::Directory.new(
            Script,
            [
              # name: AP Indices (1.2.3), path: /1
              FileSystems::Virtual::NamePath.new(
                name: Script.name_and_version_arel,
                path: Script.arel_table[:id]
              ),
              # name: AP Indices (1.2.3), path: /ap-indices_1.2.3
              FileSystems::Virtual::NamePath.new(
                name: Script.name_and_version_arel,
                path: Script.analysis_identifier_and_version_arel,
                coerce: FileSystems::Virtual::TO_S
              ),
              # name: AP Indices (latest), path: /ap-indices_latest
              FileSystems::Virtual::NamePath.new(
                name: Script.latest_version_case_statement_arel(Script.name_and_latest_version_arel),
                path: Script.latest_version_case_statement_arel(Script.analysis_identifier_and_latest_version_arel),
                coerce: FileSystems::Virtual::TO_S,
                condition: lambda { |route_param|
                             Script.latest_version_case_statement_arel(
                                Script.analysis_identifier_and_latest_version_arel
                              ).eq(route_param)
                           }
              )
            ],
            base_query_joins: :script
          )
        ),
        # represents a physical directory on disk
        # to advance to a container file system we differentiate on a container
        # being a directory if we request an API response (e.g. Accept: application/json)
        # or a container being a file if we request a file download (e.g. Accept: application/zip).
        physical: FileSystems::Physical.new(
          items_to_paths: lambda { |items|
                            items.map(&:results_absolute_path)
                          }
        ),
        # represents a sqlite database or any other container file (e.g. zip)
        container: FileSystems::Container.new
      )
    }

    def base_route_path(*other_segments)
      initial = "/analysis_jobs/#{analysis_job_id}/tree"

      return initial if other_segments.blank?

      other_segments = other_segments.map(&:to_s).join('/')
      "#{initial}/#{other_segments}"
    end

    describe 'the root level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: '/',
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(audio_recording: { site: { region: :project } })
            .count('DISTINCT projects.id')
        },
        create: lambda { |i|
          project = create(:project, name: "project_#{i}")
          region = create(:region, name: "region_#{i}", project:)
          site = create(:site, name: "site_#{i}", region:)
          audio_recording = create(:audio_recording, site:)
          create(:analysis_jobs_item, audio_recording:, analysis_job:)
        }
      )
    end

    describe 'the project level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}" },
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(audio_recording: { site: { region: :project } })
            .count('DISTINCT regions.id')
        },
        create: lambda { |i|
          region = create(:region, name: "region_#{i}", project:)
          site = create(:site, name: "site_#{i}", region:)
          audio_recording = create(:audio_recording, site:)
          create(:analysis_jobs_item, audio_recording:, analysis_job:)
        }
      )
    end

    describe 'the region level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}/#{region.id}" },
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(audio_recording: { site: { region: :project } })
            .count('DISTINCT sites.id')
        },
        create: lambda { |i|
          site = create(:site, name: "site_#{i}", region:)
          audio_recording = create(:audio_recording, site:)
          create(:analysis_jobs_item, audio_recording:, analysis_job:)
        }
      )
    end

    describe 'the site level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}/#{region.id}/#{site.id}" },
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(audio_recording: { site: { region: :project } })
            .count('DISTINCT EXTRACT(YEAR FROM audio_recordings.recorded_date)')
        },
        create: lambda { |i|
          # 1950 so we don't overlap with the default year
          audio_recording = create(:audio_recording, site:, recorded_date: Date.new(1950 + i, 1, 1))
          create(:analysis_jobs_item, audio_recording:, analysis_job:)
        }
      )
    end

    describe 'the year level' do
      around do |example|
        original_tz = Time.zone
        Zonebie.backend.zone = ActiveSupport::TimeZone['UTC']

        example.run

        Zonebie.backend.zone = original_tz
      end

      before do
        # fixture setup is too complicated for our helper so we'll just do it here
        start_date = Date.new(recording_one.recorded_date.year, 1, 1)
        12.times do |i|
          audio_recording = create(
            :audio_recording,
            site:,
            recorded_date: start_date.advance(months: i),
            notes: { item: "note number #{i}" }
          )

          create(:analysis_jobs_item, audio_recording:, analysis_job:)
        end
      end

      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}/#{region.id}/#{site.id}/#{year}" },
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(audio_recording: { site: { region: :project } })
            .count('DISTINCT EXTRACT(MONTH FROM audio_recordings.recorded_date)')
        },
        create: lambda { |_i|
          raise NotImplementedError, 'fixture should have correct count'
        },
        # max count will only be 12 since we're partitioning by month
        test_total: 12
      )
    end

    describe 'the month level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}" },
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(audio_recording: { site: { region: :project } })
            .count('DISTINCT audio_recordings.id')
        },
        create: lambda { |i|
          audio_recording = create(
            :audio_recording,
            site:,
            recorded_date: Date
              .new(recording_one.recorded_date.year, recording_one.recorded_date.month, 29)
              .advance(hours: i)
          )
          create(:analysis_jobs_item, audio_recording:, analysis_job:)
        }
      )
    end

    describe 'the recording level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}" },
        count: lambda {
          analysis_job
            .analysis_jobs_items
            .joins(:script)
            .count('DISTINCT scripts.id')
        },
        create: lambda { |i|
          script = create(:script, analysis_identifier: "script_#{i}")
          create(:analysis_jobs_item, script:, analysis_job:, audio_recording: recording_one)
        }
      )
    end

    describe 'the script level' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: -> { "/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}/#{script_one.id}" },
        count: lambda {
          item_one.results_absolute_path.children.reject(&:hidden?).count
        },
        create: lambda { |i|
          item_one.results_absolute_path.join("file_#{i}").touch
        }
      )
    end

    describe 'a directory' do
      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: lambda {
                 "/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}/#{script_one.id}/empty_dir"
               },
        count: lambda {
          item_one.results_absolute_path.join('empty_dir').children.reject(&:hidden?).count
        },
        create: lambda { |i|
          item_one.results_absolute_path.join('empty_dir', "test_#{i}").touch
        }
      )
    end

    describe 'a zip container' do
      require 'zip'

      # the container is a little harder to modify on the fly
      # so we'll just create a zip file with 25 files in it
      before do
        zip = item_one.results_absolute_path.join('special_zip.zip')
        Zip::File.open(zip, create: true) do |zip_file|
          (1..25).each do |filename|
            zip_file.get_output_stream("#{filename}.txt") { |f|
              f.puts 'Hello from Zip::File'
            }
          end
        end
      end

      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: lambda {
                 "/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}/#{script_one.id}/special_zip.zip"
               },
        count: lambda {
          25
        },
        create: lambda { |_i|
          raise NotImplementedError, 'fixture should have correct count'
        }
      )
    end

    describe 'a sqlite container' do
      # the container is a little harder to modify on the fly
      # so we'll just create a sqlite file with 25 'files' in it
      before do
        path = item_one.results_absolute_path.join('special.sqlite3')
        SQLite3::Database.new(path.to_s) do |db|
          db.execute('CREATE TABLE files (path TEXT PRIMARY KEY, blob BLOB NOT NULL, accessed INTEGER NOT NULL, created INTEGER NOT NULL, written INTEGER NOT NULL)')
          (1..25).each do |i|
            db.execute(%{INSERT INTO files  VALUES ("/test_#{i}.txt", "Hello from SQLite3", 0, 0, 0)})
          end
        end
      end

      it_behaves_like 'a pageable resource', PageableOptions.new(
        route: lambda {
                 "/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}/#{script_one.id}/special.sqlite3"
               },
        count: lambda {
          25
        },
        create: lambda { |_i|
          raise NotImplementedError, 'fixture should have correct count'
        }
      )
    end
  end
end
