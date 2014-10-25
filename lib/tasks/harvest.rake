namespace :baw do
  namespace :action do
    namespace :harvest do
      namespace :resque do

        desc 'Enqueue files to harvest using Resque'
        task :from_files, [:settings_file] => ['worker:init_redis'] do |t, args|

          file_hashes = BawWorkers::Harvest::Action.action_gather_files
          file_hashes.each do |file_hash|
            BawWorkers::Harvest::Action.action_enqueue(file_hash)
          end

        end

      end

      namespace :standalone do

        desc 'Harvest audio files directly'
        task :from_files, [:settings_file] => ['worker:init_settings'] do |t, args|

          file_hashes = BawWorkers::Harvest::Action.action_gather_files
          file_hashes.each do |file_hash|
            BawWorkers::AudioCheck::Action.action_perform(file_hash)
          end

        end

      end
    end
  end
end