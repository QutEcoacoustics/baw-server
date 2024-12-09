# frozen_string_literal: true

require_relative '../route_set_context'

describe 'RouteSet' do
  include_context 'with route set context'

  describe 'containers' do
    def base_route_path(*other_segments)
      initial = "/analysis_jobs/#{analysis_job_id}/items"

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
          FileSystems::Virtual::Directory.new(AnalysisJobsItem)
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

    describe 'zips' do
      it 'the parent shows a container that looks like a file and a directory' do
        result = route_set.show("/#{item_one.id}/zip", 'application/json', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.children.first).to be_a(FileSystems::Structs::DirectoryFile)
        expect(result.to_h).to match(
          path: base_route_path(item_one.id, 'zip'),
          name: 'zip',
          analysis_job_id:,
          analysis_jobs_item_ids: [item_one.id],
          total_count: 1,
          children: [
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip'),
              name: 'compressed.zip',
              size: Fixtures.zip_fixture.size,
              mime: 'application/zip',
              has_children: true
            }
          ]
        )
      end

      it 'vary the response based on the Accept header' do
        result = route_set.show("/#{item_one.id}/zip/compressed.zip", 'application/zip', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::FileWrapper)

        path = item_one.results_absolute_path / 'zip' / 'compressed.zip'
        expect(result.modified).to eq(path.mtime)

        result = route_set.show("/#{item_one.id}/zip/compressed.zip", 'application/json', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      end

      it 'can show results inside the container' do
        result = route_set.show("/#{item_one.id}/zip/compressed.zip", 'application/json', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.to_h).to match(
          path: base_route_path(item_one.id, 'zip', 'compressed.zip'),
          name: 'compressed.zip',
          analysis_job_id:,
          analysis_jobs_item_ids: [item_one.id],
          total_count: 5,
          children: [
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'empty'),
              name: 'empty',
              has_children: false
            },
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'New Folder'),
              name: 'New Folder',
              has_children: true
            },
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'zippeddir'),
              name: 'zippeddir',
              has_children: true
            },
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'IMG_night.jpg'),
              name: 'IMG_night.jpg',
              size: 2_703_693,
              mime: 'image/jpeg'
            },
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'test.txt'),
              name: 'test.txt',
              size: 12,
              mime: 'text/plain'
            }
          ]
        )
      end

      it 'can return an IO for a file in a container' do
        result = route_set.show("/#{item_one.id}/zip/compressed.zip/IMG_night.jpg", 'application/json', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::FileWrapper)

        path = item_one.results_absolute_path / 'zip' / 'compressed.zip'
        expect(result.to_h).to match(
          path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'IMG_night.jpg'),
          name: 'IMG_night.jpg',
          size: 2_703_693,
          mime: 'image/jpeg',
          io: an_instance_of(Zip::InputStream),
          modified: path.mtime
        )
      end

      it 'can show results two-levels deep' do
        result = route_set.show("/#{item_one.id}/zip/compressed.zip/zippeddir", 'application/json', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.to_h).to match(
          path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'zippeddir'),
          name: 'zippeddir',
          analysis_job_id:,
          analysis_jobs_item_ids: [item_one.id],
          total_count: 2,
          children: [
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'zippeddir', 'data.csv'),
              name: 'data.csv',
              size: 95,
              mime: 'text/csv'
            },
            {
              path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'zippeddir',
                Fixtures.audio_file_mono29.basename),
              name: Fixtures.audio_file_mono29.basename.to_s,
              size: Fixtures.audio_file_mono29.size,
              mime: 'audio/ogg'
            }
          ]
        )
      end

      it 'can return an IO for a file two-levels deep' do
        result = route_set.show("/#{item_one.id}/zip/compressed.zip/zippeddir/data.csv", 'application/json', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::FileWrapper)

        path = item_one.results_absolute_path / 'zip' / 'compressed.zip'
        expect(result.to_h).to match(
          path: base_route_path(item_one.id, 'zip', 'compressed.zip', 'zippeddir', 'data.csv'),
          name: 'data.csv',
          size: 95,
          mime: 'text/csv',
          io: an_instance_of(Zip::InputStream),
          modified: path.mtime
        )
      end

      describe 'root edge case' do
        before do
          link_analysis_result_file(item_one, Pathname('compressed.zip'), target: Fixtures.zip_fixture)
        end

        it 'works for a container at the root level' do
          result = route_set.show("/#{item_one.id}/compressed.zip", 'application/json', nil, analysis_job_id:)
          expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
          expect(result.to_h).to match(
            path: base_route_path(item_one.id, 'compressed.zip'),
            name: 'compressed.zip',
            analysis_job_id:,
            analysis_jobs_item_ids: [item_one.id],
            total_count: 5,
            children: a_collection_including(
              {
                path: base_route_path(item_one.id, 'compressed.zip', 'test.txt'),
                name: 'test.txt',
                size: 12,
                mime: 'text/plain'
              }
            )
          )
        end
      end
    end
  end
end
