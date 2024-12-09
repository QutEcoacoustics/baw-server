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
        # or a container being a file if we request a file download (e.g. Accept: application/x-sqlite3).
        physical: FileSystems::Physical.new(
          items_to_paths: lambda { |items|
                            items.map(&:results_absolute_path)
                          }
        ),
        # represents a sqlite database or any other container file (e.g. zip)
        container: FileSystems::Container.new
      )
    }

    describe 'sqlite' do
      it 'the parent shows a container that looks like a file and a directory' do
        result = route_set.show("/#{item_two.id}/tiles-analysis", 'application/json', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.children.first).to be_a(FileSystems::Structs::DirectoryFile)
        expect(result.to_h).to match(
          path: base_route_path(item_two.id, 'tiles-analysis'),
          name: 'tiles-analysis',
          analysis_job_id:,
          analysis_jobs_item_ids: [item_two.id],
          total_count: 1,
          children: [
            {
              path: base_route_path(item_two.id, 'tiles-analysis', 'tiles.sqlite3'),
              name: 'tiles.sqlite3',
              size: Fixtures.sqlite_fixture.size,
              mime: 'application/x-sqlite3',
              has_children: true
            }
          ]
        )
      end

      it 'vary the response based on the Accept header' do
        result = route_set.show("/#{item_two.id}/tiles-analysis/tiles.sqlite3", 'application/x-sqlite3', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::FileWrapper)

        path = item_two.results_absolute_path / 'tiles-analysis' / 'tiles.sqlite3'
        expect(result.modified).to eq(path.mtime)

        result = route_set.show("/#{item_two.id}/tiles-analysis/tiles.sqlite3", 'application/json', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
      end

      def expected_sqlite_child(name)
        {
          path: base_route_path(item_two.id, 'tiles-analysis', 'tiles.sqlite3', name[1..]),
          name: File.basename(name[1..]),
          size: Fixtures::SQLITE_FIXTURE_FILES[name],
          mime: 'image/png'
        }
      end

      it 'can show results inside the container' do
        result = route_set.show("/#{item_two.id}/tiles-analysis/tiles.sqlite3", 'application/json', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.to_h).to match(
          path: base_route_path(item_two.id, 'tiles-analysis', 'tiles.sqlite3'),
          name: 'tiles.sqlite3',
          analysis_job_id:,
          analysis_jobs_item_ids: [item_two.id],
          total_count: 7,
          children: [
            {
              path: base_route_path(item_two.id, 'tiles-analysis', 'tiles.sqlite3', 'sub_dir_1'),
              name: 'sub_dir_1',
              has_children: true
            },
            {
              path: base_route_path(item_two.id, 'tiles-analysis', 'tiles.sqlite3', 'sub_dir_2'),
              name: 'sub_dir_2',
              has_children: true
            },
            expected_sqlite_child('/BLENDED.Tile_20160727T110000Z_120.png'),
            expected_sqlite_child('/BLENDED.Tile_20160727T110000Z_240.png'),
            expected_sqlite_child('/BLENDED.Tile_20160727T110000Z_60.png'),
            expected_sqlite_child('/BLENDED.Tile_20160727T123000Z_15.png'),
            expected_sqlite_child('/BLENDED.Tile_20160727T123000Z_30.png')
          ]
        )
      end

      it 'can return an IO for a file in a container' do
        result = route_set.show("/#{item_two.id}/tiles-analysis/tiles.sqlite3/BLENDED.Tile_20160727T110000Z_120.png",
          'application/json', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::FileWrapper)

        path = item_two.results_absolute_path / 'tiles-analysis' / 'tiles.sqlite3'
        expect(result.to_h).to match(
          **expected_sqlite_child('/BLENDED.Tile_20160727T110000Z_120.png'),
          io: an_instance_of(StringIO),
          modified: path.mtime
        )
      end

      it 'can show results two-levels deep' do
        result = route_set.show("/#{item_two.id}/tiles-analysis/tiles.sqlite3/sub_dir_2", 'application/json', nil,
          analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
        expect(result.to_h).to match(
          path: base_route_path(item_two.id, 'tiles-analysis', 'tiles.sqlite3', 'sub_dir_2'),
          name: 'sub_dir_2',
          analysis_job_id:,
          analysis_jobs_item_ids: [item_two.id],
          total_count: 2,
          children: [
            expected_sqlite_child('/sub_dir_2/BLENDED.Tile_20160727T123000Z_7.5.png'),
            expected_sqlite_child('/sub_dir_2/BLENDED.Tile_20160727T125230Z_7.5.png')
          ]
        )
      end

      it 'can return an IO for a file two-levels deep' do
        result = route_set.show("/#{item_two.id}/tiles-analysis/tiles.sqlite3/sub_dir_1/BLENDED.Tile_20160727T123600Z_3.2.png",
          'application/json', nil, analysis_job_id:)
        expect(result).to be_a(FileSystems::Structs::FileWrapper)

        path = item_two.results_absolute_path / 'tiles-analysis' / 'tiles.sqlite3'
        expect(result.to_h).to match(
          **expected_sqlite_child('/sub_dir_1/BLENDED.Tile_20160727T123600Z_3.2.png'),
          io: an_instance_of(StringIO),
          modified: path.mtime
        )
      end

      describe 'root edge case' do
        before do
          link_analysis_result_file(item_one, Pathname('tiles.sqlite3'), target: Fixtures.sqlite_fixture)
        end

        it 'works for a container at the root level' do
          result = route_set.show("/#{item_one.id}/tiles.sqlite3", 'application/json', nil, analysis_job_id:)
          expect(result).to be_a(FileSystems::Structs::DirectoryWrapper)
          expect(result.to_h).to match(
            path: base_route_path(item_one.id, 'tiles.sqlite3'),
            name: 'tiles.sqlite3',
            analysis_job_id:,
            analysis_jobs_item_ids: [item_one.id],
            total_count: 7,
            children: a_collection_including(
              {
                path: base_route_path(item_one.id, 'tiles.sqlite3', 'BLENDED.Tile_20160727T110000Z_120.png'),
                name: 'BLENDED.Tile_20160727T110000Z_120.png',
                size: Fixtures::SQLITE_FIXTURE_FILES['/BLENDED.Tile_20160727T110000Z_120.png'],
                mime: 'image/png'
              }
            )
          )
        end
      end
    end
  end
end
