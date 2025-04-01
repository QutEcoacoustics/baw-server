# frozen_string_literal: true

describe '/audio_recordings/downloader', :clean_by_truncation do
  extend WebServerHelper::ExampleGroup

  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  def prepare_audio_file(audio_recording)
    link_original_audio(
      target: Fixtures.audio_file_mono,

      uuid: audio_recording.uuid,
      datetime_with_offset: audio_recording.recorded_date,
      original_format: 'mp3'
    )
  end

  core_projection = '"projection":{"include":["id","recorded_date","sites.name","site_id","canonical_file_name"]}'

  describe 'the script is templated when downloaded' do
    it 'contains the logged in user\'s name' do
      get '/audio_recordings/downloader', headers: api_request_headers(reader_token)
      expect_success

      expect(response.body).to include('    $user_name = "reader"')
    end

    it 'contains an empty string in user_name when an anonymous user downloads it' do
      get '/audio_recordings/downloader', headers: api_request_headers(no_token)
      expect_success

      expect(response.body).to include('    $user_name = ""')
    end

    it 'contains the app version and host url when downloaded' do
      get '/audio_recordings/downloader', headers: api_request_headers(reader_token)
      expect_success

      expect(response.body).to include("Version #{Settings.version_string} from http://web:3000")
      expect(response.body).to include('  $workbench_url = "http://web:3000"')
    end

    it 'contains a default filter' do
      get '/audio_recordings/downloader', headers: api_request_headers(reader_token)
      expect_success

      expect(response.body).to include <<~POWERSHELL
        $filter = @'
        {"filter":{"status":{"eq":"ready"}},"sorting":{"order_by":"recorded_date","direction":"desc"},"paging":{"items":25},#{core_projection}}
        '@
      POWERSHELL
    end

    it 'contains a filter set from query string parameters' do
      get '/audio_recordings/downloader?items=5&filter_partial_match=mp3',
        headers: api_request_headers(reader_token)
      expect_success

      expect(response.body).to include <<~POWERSHELL
        $filter = @'
        {"filter":{"status":{"eq":"ready"},"or":{"media_type":{"contains":"mp3"},"status":{"contains":"mp3"},"original_file_name":{"contains":"mp3"}}},"sorting":{"order_by":"recorded_date","direction":"desc"},"paging":{"items":5},#{core_projection}}
        '@
      POWERSHELL
    end

    it 'accepts a standard filter object from the body of a POST' do
      body = {
        'filter' => {
          'id' => {
            'gt' => 2
          },
          'duration_seconds' => {
            'range' => {
              'interval' => '[1800, 3600]'
            }
          }
        },
        'paging' => {
          'items' => 10
        }
      }
      post '/audio_recordings/downloader', params: body, **api_with_body_headers(reader_token)
      expect_success

      expect(response.body).to include <<~POWERSHELL
        $filter = @'
        {"filter":{"status":{"eq":"ready"},"id":{"gt":2},"duration_seconds":{"range":{"interval":"[1800, 3600]"}}},"sorting":{"order_by":"recorded_date","direction":"desc"},"paging":{"items":10},#{core_projection}}
        '@
      POWERSHELL
    end

    it 'send the script as an attachment with a file name' do
      get '/audio_recordings/downloader', headers: api_request_headers(no_token)
      expect_success
      expect(response.headers['Content-Disposition'])
        .to match(/attachment; filename="download_audio_files.ps1".*/)
    end
  end

  describe 'the script successfully downloads files', :slow, timeout: 60 do
    let(:script) { BawApp.tmp_dir / 'download_audio_files.ps1' }

    after do
      script.delete if script.exist?
    end

    it 'checks pwsh is on path' do
      version = `pwsh -version`
      expect(version).to match(/PowerShell \d+\.\d+\.\d+\n/)
    end

    it 'checks the file has correct syntax' do
      get '/audio_recordings/downloader', headers: api_request_headers(no_token)
      expect_success

      script.write(response.body)

      result = `pwsh -c '$ErrorView = "Normal"; Get-Command -Syntax "#{script.to_path}" && echo "success"'`
      logger.info(result)

      expect(result).to match(/success/)
    end

    context 'when downloading' do
      expose_app_as_web_server

      before do
        prepare_audio_file audio_recording

        (1..10).each do |_i|
          audio_recording = create(:audio_recording, status: 'ready', site:)

          prepare_audio_file audio_recording
        end

        Dir.mkdir(BawApp.tmp_dir / 'downloader_test', 0o777)
      end

      after do
        (BawApp.tmp_dir / 'downloader_test').rmtree
      end

      it 'verified we have expected number of recordings' do
        expect(AudioRecording.count).to eq(11)

        get '/audio_recordings', **api_headers(admin_token)

        expect_success
        expect_json_response
        expect_number_of_items(11)
      end

      it 'downloads the files' do
        logger.measure_info('downloading script') do
          out_and_err, status = Open3.capture2e(
            'curl -JO localhost:3000/audio_recordings/downloader?items=2',
            chdir: BawApp.tmp_dir
          )
          logger.info(out_and_err, status:)
        end

        script.chmod(0o764)

        script_output = ''

        logger.measure_info('running download script') do
          logger.tagged('download script output') do
            auth_token = User.find_by(roles_mask: 1).authentication_token

            script_output, status = Open3.capture2e(
              "pwsh download_audio_files.ps1 -target downloader_test -auth_token #{auth_token}",
              chdir: BawApp.tmp_dir
            )
            logger.info(script_output, status:)
          end
        end

        expect(script_output).to match(
          "Downloading recordings\nGetting page 1\nGot page 1 of 6, 2 recordings in this page.\nDownloading recording"
        )
        expect(script_output).to match('Got page 6 of 6, 1 recordings in this page.')
        expect(script_output).to match(%r{Downloaded recording \d+ to downloader_test/\d+_sitename\d+/.*.mp3})

        files = (BawApp.tmp_dir / 'downloader_test').glob('**/*.mp3')
        expect(files.size).to eq(11)
        expect(files.map(&:to_s)).to all(end_with('.mp3'))
      end

      it 'downloads the files (with username and password)' do
        logger.measure_info('downloading script') do
          out_and_err, status = Open3.capture2e(
            'curl -JO localhost:3000/audio_recordings/downloader?items=2',
            chdir: BawApp.tmp_dir
          )
          logger.info(out_and_err, status:)
        end

        script.chmod(0o764)

        script_output = ''

        logger.measure_info('running download script') do
          logger.tagged('download script output') do
            script_output, status = Open3.capture2e(
              'pwsh download_audio_files.ps1 -target downloader_test -user_name admin -password password',
              chdir: BawApp.tmp_dir,
              stdin_data: "password\n"
            )
            logger.info(script_output, status:)
          end
        end

        expect(script_output).to match(
          "Downloading recordings\nGetting page 1\nGot page 1 of 6, 2 recordings in this page.\nDownloading recording"
        )
        expect(script_output).to match('Got page 6 of 6, 1 recordings in this page.')
        expect(script_output).to match(%r{Downloaded recording \d+ to downloader_test/\d+_sitename\d+/.*.mp3})

        files = (BawApp.tmp_dir / 'downloader_test').glob('**/*.mp3')
        expect(files.size).to eq(11)
        expect(files.map(&:to_s)).to all(end_with('.mp3'))
      end
    end
  end
end
