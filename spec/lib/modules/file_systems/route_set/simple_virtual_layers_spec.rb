# frozen_string_literal: true

require_relative 'route_set_context'

describe 'RouteSet' do
  include_context 'with route set context'

  describe 'simple virtual layers' do
    def base_route_path(*other_segments)
      initial = "/analysis_jobs/#{analysis_job_id}/results"

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
            AudioRecording,
            FileSystems::Virtual::NamePath.new(
              name: AudioRecording::FRIENDLY_NAME_AREL,
              path: AudioRecording.arel_table[:id]
            ),
            base_query_joins: :audio_recording,
            include_base_ids: true
          ),
          FileSystems::Virtual::Directory.new(
            Script,
            :id,
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
        container: nil #FileSystems::Container.new(:path)
      )
    }

    it 'works' do
      expect(route_set).to be_a(FileSystems::RouteSet)
    end

    it 'can list audio recordings' do
      result = route_set.show('/', 'application/json', nil,
        analysis_job_id:)
      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.to_h).to match(
        path: base_route_path,
        name: '',
        analysis_job_id:,

        total_count: 2,
        children: [
          {
            path: base_route_path(recording_one.id),
            name: recording_one.friendly_name,
            has_children: true,
            link: "/audio_recordings/#{recording_one.id}"
          },
          {
            path: base_route_path(recording_two.id),
            name: recording_two.friendly_name,
            has_children: true,
            link: "/audio_recordings/#{recording_two.id}"
          }
        ]
      )
    end

    it 'can list scripts' do
      result = route_set.show("/#{recording_two.id}", 'application/json', nil,
        analysis_job_id:)
      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_two.id),
        name: recording_two.friendly_name,
        analysis_job_id:,
        analysis_jobs_item_ids: item_ids_for(recording_two),
        total_count: 2,
        link: "/audio_recordings/#{recording_two.id}",
        children: [
          {
            path: base_route_path(recording_two.id, script_one.id),
            name: script_one.id.to_s,
            has_children: true,
            link: "/scripts/#{script_one.id}"
          },
          {
            path: base_route_path(recording_two.id, script_two.id),
            name: script_two.id.to_s,
            has_children: true,
            link: "/scripts/#{script_two.id}"
          }
        ]
      )
    end

    it 'can handle showing an empty directory' do
      result = route_set.show(
        "/#{recording_two.id}/#{script_two.id}",
        'application/json',
        nil,
        analysis_job_id:
      )

      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_two.id, script_two.id),
        name: script_two.id.to_s,
        analysis_job_id:,
        analysis_jobs_item_ids: item_ids_for(recording_two, script_two),
        total_count: 0,
        children: [],
        link: "/scripts/#{script_two.id}"
      )
    end

    it 'can descend into a directory' do
      result = route_set.show(
        "/#{recording_one.id}/#{script_one.id}",
        'application/json',
        nil,
        analysis_job_id:
      )

      expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_one.id, script_one.id),
        name: script_one.id.to_s,
        analysis_job_id:,
        analysis_jobs_item_ids: item_ids_for(recording_one, script_one),
        link: "/scripts/#{script_one.id}",
        total_count: 4,
        children: [
          {
            path: base_route_path(recording_one.id, script_one.id, 'Test1'),
            name: 'Test1',
            has_children: true
          },
          {
            path: base_route_path(recording_one.id, script_one.id, 'empty_dir'),
            name: 'empty_dir',
            has_children: false
          },
          {
            path: base_route_path(recording_one.id, script_one.id, 'zip'),
            name: 'zip',
            has_children: true
          },
          {
            path: base_route_path(recording_one.id, script_one.id, 'test.log'),
            name: 'test.log',
            size: 12,
            mime: 'text/plain'
          }
        ]
      )
    end

    it 'can return a file' do
      result = route_set.show(
        "/#{recording_one.id}/#{script_one.id}/test.log",
        'application/json',
        nil,
        analysis_job_id:
      )

      expect(result).to be_a(FileSystems::Structs::FileWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_one.id, script_one.id, 'test.log'),
        name: 'test.log',
        size: 12,
        mime: 'text/plain',
        io: an_instance_of(File),
        modified: (item_one.results_absolute_path / 'test.log').mtime
      )
    end

    it 'can get a file in a directory' do
      result = route_set.show(
        "/#{recording_one.id}/#{script_two.id}/Test1/blog",
        'application/json',
        nil,
        analysis_job_id:
      )

      expect(result).to be_a(FileSystems::Structs::FileWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_one.id, script_two.id, 'Test1', 'blog'),
        name: 'blog',
        size: 24,
        mime: 'application/octet-stream',
        io: an_instance_of(File),
        modified: (item_two.results_absolute_path / 'Test1' / 'blog').mtime
      )
    end

    it 'fetches container files as normal if no container content type header is present' do
      result = route_set.show(
        "/#{recording_one.id}/#{script_one.id}/zip/compressed.zip",
        'application/json',
        nil,
        analysis_job_id:
      )

      expect(result).to be_a(FileSystems::Structs::FileWrapper)
      expect(result.to_h).to match(
        path: base_route_path(recording_one.id, script_one.id, 'zip/compressed.zip'),
        name: 'compressed.zip',
        size: Fixtures.zip_fixture.size,
        mime: 'application/zip',
        io: an_instance_of(File),
        modified: (item_one.results_absolute_path / 'zip' / 'compressed.zip').mtime
      )
    end
  end
end
