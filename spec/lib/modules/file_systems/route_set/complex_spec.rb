# frozen_string_literal: true

require_relative 'route_set_context'

describe 'RouteSet' do
  include_context 'with route set context'

  describe 'a complex route set' do
    def base_route_path(*other_segments)
      initial = "/analysis_jobs/#{analysis_job_id}/tree"

      return initial if other_segments.blank?

      other_segments = other_segments.map(&:to_s).join('/')
      "#{initial}/#{other_segments}"
    end

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
            AudioRecording::FRIENDLY_NAME_AREL,
            include_base_ids: true
          ),
          FileSystems::Virtual::Directory.new(
            Script,
            Script.name_and_version_arel,
            base_query_joins: :script,
            include_base_ids: true
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

    it 'works' do
      expect(route_set).to be_a(FileSystems::RouteSet)
    end

    it 'can list projects' do
      result = route_set.show('/', 'application/json', nil, analysis_job_id:)
      expect(result.to_h).to match(
        path: base_route_path,
        name: '',
        analysis_job_id:,
        total_count: 1,
        children: [
          {
            name: project.name,
            path: base_route_path(project.id),
            has_children: true,
            link: "/projects/#{project.id}"
          }
        ]
      )
    end

    it 'can list regions' do
      result = route_set.show("/#{project.id}", 'application/json', nil, analysis_job_id:)
      expect(result.to_h).to match(
        path: base_route_path(project.id),
        name: project.name,
        analysis_job_id:,
        link: "/projects/#{project.id}",
        total_count: 1,
        children: [
          {
            name: region.name,
            path: base_route_path(project.id, region.id),
            has_children: true,
            link: "/regions/#{region.id}"
          }
        ]
      )
    end

    it 'can list sites' do
      result = route_set.show("/#{project.id}/#{region.id}", 'application/json', nil, analysis_job_id:)
      expect(result.to_h).to match(
        path: base_route_path(project.id, region.id),
        name: region.name,
        analysis_job_id:,
        link: "/regions/#{region.id}",
        total_count: 1,
        children: [
          {
            name: site.name,
            path: base_route_path(project.id, region.id, site.id),
            has_children: true,
            link: "/sites/#{site.id}"
          }
        ]
      )
    end

    it 'can list audio recordings by year' do
      result = route_set.show("/#{project.id}/#{region.id}/#{site.id}", 'application/json', nil,
        analysis_job_id:)

      expect(result.to_h).to match(
        path: base_route_path(project.id, region.id, site.id),
        name: site.name,
        analysis_job_id:,
        link: "/sites/#{site.id}",
        total_count: 1,
        children: [
          {
            name: year,
            path: base_route_path(project.id, region.id, site.id, year),
            has_children: true,
            link: nil
          }
        ]
      )
    end

    it 'can list audio recordings by month' do
      # flaky test: sometimes the fake generator spills over a single month
      analysis_jobs_matrix[:audio_recordings].each_with_index do |recording, index|
        month = (index % 2) + 1
        recording.update!(recorded_date: Time.zone.local(year.to_i, month, 15))
        recording.save!
      end

      result = route_set.show("/#{project.id}/#{region.id}/#{site.id}/#{year}", 'application/json', nil,
        analysis_job_id:)

      expect(result.to_h).to match(
        path: base_route_path(project.id, region.id, site.id, year),
        name: year,
        analysis_job_id:,
        link: nil,
        total_count: 2,
        children: [
          {
            name: recording_one.recorded_date.strftime('%Y-%m'),
            path: base_route_path(project.id, region.id, site.id, year, recording_one.recorded_date.strftime('%Y-%m')),
            has_children: true,
            # the link here is generated in this case because only one recording is in this month
            # see the paging_spec.rb file for an example where it should still be nil
            link: "/audio_recordings/#{recording_one.id}"
          },
          {
            name: recording_two.recorded_date.strftime('%Y-%m'),
            path: base_route_path(project.id, region.id, site.id, year, recording_two.recorded_date.strftime('%Y-%m')),
            has_children: true,
            # as above
            link: "/audio_recordings/#{recording_two.id}"
          }
        ]
      )
    end

    describe 'friendly name' do
      before do
        # stabilize the test fixtures
        year = 2020
        month = 0o4

        recording_one.update!(recorded_date: Time.zone.local(year, month, 15))
        recording_two.update!(recorded_date: Time.zone.local(year, month, 16))
      end

      it 'can list audio recordings by friendly name' do
        result = route_set.show("/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}", 'application/json', nil,
          analysis_job_id:)
        expect(result.to_h).to match(
          path: base_route_path(project.id, region.id, site.id, year, month),
          name: month,
          analysis_job_id:,
          link: nil,
          total_count: 2,
          children: [
            {
              name: recording_one.friendly_name,
              path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id),
              has_children: true,
              link: "/audio_recordings/#{recording_one.id}"
            },
            {
              name: recording_two.friendly_name,
              path: base_route_path(project.id, region.id, site.id, year, month, recording_two.id),
              has_children: true,
              link: "/audio_recordings/#{recording_two.id}"
            }
          ]
        )
      end
    end

    describe 'scripts' do
      before do
        # stabilize sorting in flaky test
        script_one.update!(name: 'script A')
        script_one.update!(name: 'script B')
      end

      it 'can list scripts by name' do
        result = route_set.show("/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}",
          'application/json', nil, analysis_job_id:)
        expect(result.to_h).to match(
          path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id),
          name: recording_one.friendly_name,
          analysis_job_id:,
          analysis_jobs_item_ids: item_ids_for(recording_one),
          link: "/audio_recordings/#{recording_one.id}",
          total_count: 2,
          children: [
            {
              path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id),
              name: Script.where(id: script_one.id).pick(Script.name_and_version_arel),
              has_children: true,
              link: "/scripts/#{script_one.id}"
            },
            {
              path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_two.id),
              name: Script.where(id: script_two.id).pick(Script.name_and_version_arel),
              has_children: true,
              link: "/scripts/#{script_two.id}"
            }
          ]
        )
      end
    end

    it 'can list files in the results' do
      result = route_set.show("/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}/#{script_one.id}",
        'application/json', nil, analysis_job_id:)
      expect(result.to_h).to match(
        path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id),
        name: Script.where(id: script_one.id).pick(Script.name_and_version_arel),
        analysis_job_id:,
        analysis_jobs_item_ids: item_ids_for(recording_one, script_one),
        link: "/scripts/#{script_one.id}",
        total_count: 4,
        children: [
          {
            name: 'Test1',
            path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id,
              'Test1'),
            has_children: true
          },
          {
            name: 'empty_dir',
            path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id,
              'empty_dir'),
            has_children: false
          },
          {
            name: 'zip',
            path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id, 'zip'),
            has_children: true
          },
          {
            name: 'test.log',
            path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id,
              'test.log'),
            size: 12,
            mime: 'text/plain'
          }
        ]
      )
    end

    it 'despite all the layers we can download a file' do
      result = route_set.show("/#{project.id}/#{region.id}/#{site.id}/#{year}/#{month}/#{recording_one.id}/#{script_one.id}/zip/compressed.zip/test.txt",
        'application/json', nil, analysis_job_id:)
      expect(result).to be_an_instance_of(FileSystems::Structs::FileWrapper)
      expect(result.to_h).to match(
        path: base_route_path(project.id, region.id, site.id, year, month, recording_one.id, script_one.id, 'zip',
          'compressed.zip', 'test.txt'),
        name: 'test.txt',
        size: 12,
        mime: 'text/plain',
        io: an_instance_of(Zip::InputStream),
        modified: (item_one.results_absolute_path / 'zip' / 'compressed.zip').mtime
      )
    end
  end
end
