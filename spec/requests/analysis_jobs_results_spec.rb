# frozen_string_literal: true

describe 'AnalysisJobsResults' do
  render_error_responses
  create_entire_hierarchy

  test_file_content = '"header1", "header2", "header3"\n"content1","content2", "content2"'
  hidden_file_content = 'super secret content'

  before do
    create_analysis_result_file(analysis_jobs_item, Pathname('Test1/Test2/test-CASE.csv'), content: test_file_content)
    link_analysis_result_file(analysis_jobs_item, Pathname('tiles.sqlite3'), target: Fixtures.sqlite_fixture)
    link_analysis_result_file(analysis_jobs_item, Pathname('compressed.zip'), target: Fixtures.zip_fixture)
    create_analysis_result_file(analysis_jobs_item, Pathname('.hidden'), content: 'super secret content')
  end

  # most of the tests for the virtual filesystem are in the lib/modules/file_systems/route_set folder.
  # We're only going test anything that's not in there and the mounting in the controller.

  RSpec.shared_examples 'downloading results' do |base_path, query_path_lambda, analysis_job_id_lambda|
    describe base_path do
      let(:hidden_file) {
        {
          name: '.hidden',
          path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/.hidden",
          size: 20,
          mime: 'application/octet-stream'
        }
      }

      let(:query_path) { instance_exec(&query_path_lambda) }
      let(:analysis_job_id) { instance_exec(&analysis_job_id_lambda) }

      it 'can list the base_path' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}", **api_headers(reader_token)

        expect_success
        expect(api_data).to match(a_hash_including(
          {
            path: "/analysis_jobs/#{analysis_job_id}/#{base_path}",
            name: '',
            analysis_job_id: analysis_job.id,
            children: an_instance_of(Array).and(have_at_least(1).items)
          }
        ))
      end

      it 'can list real files in the first physical layer' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}", **api_headers(reader_token)

        expect_success
        expect(api_data).to match(a_hash_including(
          {
            path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}",
            name: Script.where(id: script.id).pick(Script.name_and_version_arel),
            analysis_job_id: analysis_job.id,
            children: an_instance_of(Array).and(have_at_least(1).items).and(a_collection_excluding(hidden_file))
          }
        ))
      end

      it 'as admin, can list real files in the first physical layer and show hidden files' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}", **api_headers(admin_token)

        expect_success
        expect(api_data).to match(a_hash_including(
          {
            path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}",
            name: Script.where(id: script.id).pick(Script.name_and_version_arel),
            analysis_job_id: analysis_job.id,
            children: a_collection_including(hidden_file)
          }
        ))
      end

      it 'can list a directory' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2", **api_headers(reader_token)

        expect_success
        expect(api_data).to match(
          {
            path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2",
            name: 'Test2',
            analysis_job_id: analysis_job.id,
            analysis_jobs_item_ids: [analysis_jobs_item.id],
            children: [
              {
                name: 'test-CASE.csv',
                path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2/test-CASE.csv",
                size: test_file_content.size,
                mime: 'text/csv'
              }
            ]
          }
        )
      end

      it 'can head a directory' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2", **api_headers(reader_token)

        bytes = response_body.size

        head "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2", **api_headers(reader_token)

        expect_success

        expect(response.content_length).to eq bytes
      end

      it 'can download a file' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2/test-CASE.csv",
          **api_headers(reader_token)

        expect_success
        expect(response.body).to eq test_file_content
        expect(response.content_type).to eq 'text/csv'
      end

      it 'can head a file' do
        head "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/Test1/Test2/test-CASE.csv",
          **api_headers(reader_token)

        expect_success
        expect(response.content_length).to eq test_file_content.size
        expect(response.content_type).to eq 'text/csv'
      end

      it 'admins can download a hidden files' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/.hidden", **api_headers(admin_token)

        expect_success
        expect(response.body).to eq hidden_file_content
        expect(response.content_type).to eq 'application/octet-stream'
      end

      it 'non-admins cannot download a hidden files' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/.hidden",
          **api_headers(reader_token)

        expect_error(:bad_request, 'The requested url contains illegal characters')
      end

      it 'can download a file from inside a zip' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/compressed.zip/IMG_night.jpg",
          **api_headers(reader_token)

        expect_success

        expect(response).to be_same_file_as(Fixtures.bowra2_image_jpeg.open)
        expect(response.content_type).to eq 'image/jpeg'
      end

      it 'can head a file from inside a zip' do
        head "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/compressed.zip/IMG_night.jpg",
    **api_headers(reader_token)

        expect_success
        expect(response.content_length).to eq Fixtures.bowra2_image_jpeg.size
        expect(response.content_type).to eq 'image/jpeg'
      end

      it 'can download the whole zip' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/compressed.zip",
          **api_headers(reader_token, accept: 'application/zip')

        expect_success
        expect(response).to be_same_file_as(Fixtures.zip_fixture)
        expect(response.content_type).to eq 'application/zip'
      end

      it 'can download a file from inside a sqlite3' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/tiles.sqlite3/BLENDED.Tile_20160727T110000Z_120.png",
    **api_headers(reader_token)

        expect_success
        expect(response.content_length).to eq Fixtures::SQLITE_FIXTURE_FILES['/BLENDED.Tile_20160727T110000Z_120.png']
        expect(response.content_type).to eq 'image/png'
      end

      it 'can head a file from inside a sqlite3' do
        head "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/tiles.sqlite3/BLENDED.Tile_20160727T110000Z_120.png",
    **api_headers(reader_token)

        expect_success
        expect(response.content_length).to eq Fixtures::SQLITE_FIXTURE_FILES['/BLENDED.Tile_20160727T110000Z_120.png']
        expect(response.content_type).to eq 'image/png'
      end

      it 'can download the whole sqlite3 file' do
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/tiles.sqlite3",
          **api_headers(reader_token, accept: 'application/x-sqlite3')

        expect_success
        expect(response).to be_same_file_as(Fixtures.sqlite_fixture)
        expect(response.content_type).to eq 'application/x-sqlite3'
      end
    end
  end

  it_behaves_like 'downloading results', 'results', -> { "/#{audio_recording.id}/#{script.id}" }, -> { analysis_job.id }

  it_behaves_like 'downloading results', 'artifacts',
    lambda {
      "/#{project.id}/#{region.id}/#{site.id}/#{audio_recording.recorded_date.strftime('%Y')}/#{audio_recording.recorded_date.strftime('%Y-%m')}/#{audio_recording.id}/#{script.id}"
    }, -> { analysis_job.id }

  describe 'system jobs' do
    before do
      analysis_job.system_job = true
      analysis_job.project_id = nil
      analysis_job.save!
    end

    it_behaves_like 'downloading results', 'results', -> { "/#{audio_recording.id}/#{script.id}" }, -> { 'system' }

    it_behaves_like 'downloading results', 'artifacts',
      lambda {
        "/#{project.id}/#{region.id}/#{site.id}/#{audio_recording.recorded_date.strftime('%Y')}/#{audio_recording.recorded_date.strftime('%Y-%m')}/#{audio_recording.id}/#{script.id}"
      }, -> { 'system' }
  end

  describe 'alternate named routes' do
    before do
      provenance = script.provenance
      provenance.version = '1.2.3'
      provenance.save!
      new_provenance = provenance.dup
      new_provenance.version = '1.2.4'
      new_provenance.save!

      script.update!(name: 'alternate-name', analysis_identifier: 'alternate-identifier')
      new_script = script.dup
      new_script.version = new_script.version + 1
      new_script.provenance = new_provenance
      new_script.save!

      analysis_job.scripts << new_script
      analysis_job.save!

      new_item = create(:analysis_jobs_item, analysis_job:, audio_recording:, script: script.latest_version)

      link_analysis_result_file(new_item, Fixtures.bowra2_image_jpeg.basename, target: Fixtures.bowra2_image_jpeg)

      expect(script.analysis_identifier).to eq('alternate-identifier')
      expect(new_script.analysis_identifier).to eq('alternate-identifier')

      script.reload
      expect(script.provenance.version).to eq('1.2.3')
      expect(new_script.provenance.version).to eq('1.2.4')
    end

    [
      ['results', -> { "/#{audio_recording.id}" }],
      [
        'artifacts',
        lambda {
          "/#{project.id}/#{region.id}/#{site.id}/#{audio_recording.recorded_date.strftime('%Y')}/#{audio_recording.recorded_date.strftime('%Y-%m')}/#{audio_recording.id}"
        }
      ]
    ].each do |base_path, query_path_lambda|
      let(:base_path) { base_path }
      let(:query_path) { instance_exec(&query_path_lambda) }
      let(:new_script) { script.latest_version }
      let(:analysis_job_id) { analysis_job.id }
      let(:new_item) { analysis_job.analysis_jobs_items.where(script_id: new_script.id).first }

      def expect_common(script_token, expected_name)
        get "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/#{script_token}", **api_headers(reader_token)

        expect_success
        expect(api_data).to match(
          {
            path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/#{script_token}",
            name: expected_name,
            analysis_job_id: analysis_job.id,
            analysis_jobs_item_ids: [new_item.id],
            link: "/scripts/#{new_script.id}",
            children: a_collection_including(
              {
                name: Fixtures.bowra2_image_jpeg.basename.to_s,
                path: "/analysis_jobs/#{analysis_job_id}/#{base_path}#{query_path}/#{script_token}/" + Fixtures.bowra2_image_jpeg.basename.to_s,
                size: Fixtures.bowra2_image_jpeg.size,
                mime: 'image/jpeg'
              }
            )
          }
        )
      end

      describe base_path do
        it 'can list using a script identifier and version' do
          script_token = 'alternate-identifier_1.2.4'

          expect_common(script_token, 'alternate-name (1.2.4)')
        end

        it 'can still list via the script id' do
          script_token = new_script.id

          expect_common(script_token, 'alternate-name (1.2.4)')
        end

        it 'can list using just the analysis identifier which will return the latest version' do
          script_token = 'alternate-identifier_latest'

          expect_common(script_token, 'alternate-name (latest)')
        end
      end
    end
  end
end
