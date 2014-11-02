namespace :baw do
  namespace :action do
    namespace :harvest do
      namespace :resque do

        desc 'Enqueue files to harvest using Resque'
        task :from_files, [:settings_file] => %w(baw:common:init_rake_task baw:common:init_redis) do |t, args|

          gather_files = BawWorkers::Harvest::Action.action_gather_files
          to_do_path = BawWorkers::Settings.actions.harvest.to_do_path
          file_hashes = gather_files.run(to_do_path)

          file_hashes.each do |file_hash|
            BawWorkers::Harvest::Action.action_enqueue(file_hash)
          end

        end

      end

      namespace :standalone do

        desc 'Harvest audio files directly'
        task :from_files, [:settings_file] => ['baw:common:init_rake_task'] do |t, args|

          gather_files = BawWorkers::Harvest::Action.action_gather_files
          to_do_path = BawWorkers::Settings.actions.harvest.to_do_path
          file_hashes = gather_files.run(to_do_path)

          file_hashes.each do |file_hash|
            BawWorkers::AudioCheck::Action.action_perform(file_hash)
          end

        end

      end
    end
  end
end