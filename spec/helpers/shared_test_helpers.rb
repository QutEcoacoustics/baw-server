# frozen_string_literal: true

shared_context 'shared_test_helpers' do
  let(:host) { Settings.api.host }
  let(:port) { Settings.api.port }
  let(:scheme) { 'https' }
  let(:default_uri) { "#{scheme}://#{host}:#{port}" }

  # example files
  let(:example_media_dir) { Fixtures::FILES_PATH }

  let(:audio_file_mono) { Fixtures.audio_file_mono }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_format) { 'ogg' }
  let(:audio_file_mono_sample_rate) { 44_100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }
  let(:audio_file_mono_data_length_bytes) { 822_281 }
  let(:audio_file_mono_bit_rate_bps) { 239_920 }

  let(:audio_file_mono_29) { Fixtures.audio_file_mono }
  let(:audio_file_mono_29_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_29_format) { 'ogg' }
  let(:audio_file_mono_29_sample_rate) { 44_100 }
  let(:audio_file_mono_29_channels) { 1 }
  let(:audio_file_mono_29_duration_seconds) { 29.0 }
  let(:audio_file_mono_29_data_length_bytes) { 296_756 }
  let(:audio_file_mono_29_bit_rate_bps) { 239_920 }

  let(:audio_file_wac) { Fixtures.audio_file_wac_1 }

  let(:duration_range) { 0.11 }

  let(:audio_file_corrupt) { Fixtures.audio_file_corrupt }

  let(:temporary_dir) { Settings.paths.temp_dir }

  # output file paths
  let(:program_stderr_file) { Settings.resque.error_log_file }
  let(:program_stderr_content) { File.read(program_stderr_file) }

  let(:program_stdout_file) { Settings.resque.output_log_file }
  let(:program_stdout_content) { File.read(program_stdout_file) }

  let(:worker_log_file) { Settings.paths.worker_log_file }
  let(:worker_log_content) {  File.read(worker_log_file) }

  let(:default_settings_file) { RSpec.configuration.default_settings_path }
  let(:harvest_to_do_path) { File.expand_path(Settings.actions.harvest.to_do_path) }
  let(:custom_temp) { BawWorkers::Config.temp_dir }

  # easy access to config & settings
  let(:audio) { BawWorkers::Config.audio_helper }
  let(:spectrogram) { BawWorkers::Config.spectrogram_helper }

  let(:audio_original) { BawWorkers::Config.original_audio_helper }
  let(:audio_cache) { BawWorkers::Config.audio_cache_helper }
  let(:spectrogram_cache) { BawWorkers::Config.spectrogram_cache_helper }
  let(:analysis_cache) { BawWorkers::Config.analysis_cache_helper }

  let(:logger) { BawWorkers::Config.logger_worker }
  let(:file_info) { BawWorkers::Config.file_info }
  let(:api) { BawWorkers::Config.api_communicator }

  let(:api_security_response) {}

  def create_original_audio(options, example_file_name, new_name_style = false, delete_other = false)
    # ensure :datetime_with_offset is an ActiveSupport::TimeWithZone object
    if options.include?(:datetime_with_offset) && options[:datetime_with_offset].is_a?(ActiveSupport::TimeWithZone)
      # all good - no op
    elsif options.include?(:datetime_with_offset) && options[:datetime_with_offset].end_with?('Z')
      options[:datetime_with_offset] = Time.zone.parse(options[:datetime_with_offset])
    else
      raise ArgumentError, "recorded_date must be a UTC time (i.e. end with Z), given '#{options[:datetime_with_offset]}'."
    end

    original_possible_paths = audio_original.possible_paths(options)

    file_to_make = new_name_style ? original_possible_paths.second : original_possible_paths.first
    file_to_delete = new_name_style ? original_possible_paths.first : original_possible_paths.second

    File.delete(file_to_delete) if delete_other && File.exist?(file_to_delete)
    FileUtils.mkpath File.dirname(file_to_make)
    FileUtils.cp example_file_name, file_to_make

    file_to_make
  end

  def clear_original_audio
    paths = Settings.paths.original_audios

    clear_directories(paths)
  end

  def clear_spectrogram_cache
    paths = Settings.paths.cached_spectrograms

    clear_directories(paths)
  end

  def clear_audio_cache
    paths = Settings.paths.cached_audios

    clear_directories(paths)
  end

  def clear_analysis_cache
    paths = Settings.paths.cached_analysis_jobs

    clear_directories(paths)
  end

  def clear_harvester_to_do
    paths = [harvest_to_do_path]
    clear_directories(paths, '/tmp/_harvester_to_do_path')
  end

  def clear_directories(directories, sanity_check = '_test_')
    directories.each do |path|
      raise "Will not delete #{path} because it does not contain '#{sanity_check}'" unless path =~ /#{sanity_check}/

      # some of these dirs are referenced on shared file systems (e.g. Docker)
      # thus, don't remove dir, clear contents
      path = Pathname(path)
      next unless path.exist?

      path.children.each { |entry|
        entry.rmtree unless entry.basename.to_s == '.gitkeep'
      }
    end
  end

  def expect_empty_directories(directories)
    aggregate_failures do
      directories.each do |path|
        path = Pathname(path)
        next unless path.exist?

        expect(path.empty?).to be(true), lambda {
          children = path.children.each(&:to_s).join("\n")

          "Expected #{path} to be empty but it contained:\n#{children}"
        }
      end
    end
  end

  def make_original_audio
    paths = Settings.paths.original_audios

    paths.each do |path|
      raise "Will not create #{path} because it does not contain 'test'" unless path =~ /_test_/

      FileUtils.mkdir path unless Dir.exist? path
    end
  end

  def get_cached_audio_paths(options)
    audio_cache.possible_paths(options)
  end

  def get_cached_spectrogram_paths(options)
    spectrogram_cache.possible_paths(options)
  end

  def copy_test_audio_check_csv
    csv_file_example = Fixtures.audio_check_csv

    FileUtils.mkpath(custom_temp)
    csv_file = File.join(custom_temp, '_audio_check_to_do.csv')

    FileUtils.cp(csv_file_example, csv_file)

    csv_file
  end

  def copy_test_programs
    echo = Pathname.new(BawWorkers::Config.programs_dir) / 'echo'
    touch = Pathname.new(BawWorkers::Config.programs_dir) / 'touch'
    return if echo.exist? && touch.exist?

    FileUtils.cp('/bin/echo', echo)
    FileUtils.cp('/usr/bin/touch', touch)
  end

  def copy_worker_config
    settings_file_src = File.join(BawApp.root, 'config', 'settings', 'default.yml')
    settings_file_dest = File.join(BawApp.root, 'tmp', 'default.yml')

    FileUtils.cp(settings_file_src, settings_file_dest)

    settings_file_dest
  end

  def emulate_resque_worker(queue)
    job = Resque.reserve(queue)

    # returns true if job was performed
    job.perform
  end

  # http://robots.thoughtbot.com/test-rake-tasks-like-a-boss
  # http://pivotallabs.com/how-i-test-rake-tasks/

  # let(:rake_application) {
  #   Rake.application
  # }

  def run_rake_task(task_name, args)
    the_task = Rake::Task[task_name]

    the_task.application.options.trace = true

    #args = [] if args.blank?
    #task_args = Rake::TaskArguments.new(the_task.arg_names, args)
    #the_task.execute(task_args)

    the_task.reenable
    the_task.invoke(*args)
  end

  #let(:rake_task_path)          { File.join('tasks', "#{rake_task_name.split(':').second}") }
  #subject { Rake::Task[rake_task_name] }

  # let :top_level_path do
  #   File.join(File.dirname(__FILE__), '..', '..', '..')
  # end
  #
  # let :run_rake_task do
  #   subject.reenable
  #   Rake.application.invoke_task rake_task_name
  # end

  # def loaded_files_excluding_current_rake_file
  #   $".reject {|file| file == File.join(top_level_path, ("#{task_path}.rake")) }
  # end

  # before do
  #   #Rake.application = rake
  #   #Rake.application.rake_require(rake_task_path, [top_level_path.to_s], loaded_files_excluding_current_rake_file)
  #   Rake.application.rake_require(rake_task_path)
  #
  #   #Rake::Task.define_task(:environment)
  # end

  def get_api_security_response(user_name, auth_token)
    {
      meta: {
        status: 200,
        message: 'OK'
      },
      data: {
        auth_token: auth_token,
        user_name: user_name,
        message: 'Signed in successfully.'
      }
    }
  end

  def get_api_security_request(email, password)
    {
      email: email,
      password: password
    }
  end

  def expect_requests_made_in_order(*expected_requests)
    actual_requests = []

    WebMock.after_request do |request_signature|
      actual_requests.push(request_signature)
    end

    # run the actual functions
    yield

    expected_requests.each_index do |index|
      expected_request = expected_requests[index]
      expect(expected_request).to have_been_made.once

      matches = expected_request.matches?(actual_requests[index])
      expect(matches).to be_truthy, "Request order does not match, expected:\n\n#{expected_request}\n\nIn position #{index}, got\n\n#{actual_requests[index]}"
    end
  end
end
