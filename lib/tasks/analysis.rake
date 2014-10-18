namespace :baw do
  namespace :action do
    namespace :analysis do
      namespace :resque do

        desc 'Enqueue files to analyse using Resque'
        task :from_files, [:settings_file] => ['worker:init_redis'] do |t, args|

        end

      end

      namespace :standalone do


        desc 'Analyse audio files directly'
        task :from_files, [:settings_file] => ['worker:init_settings'] do |t, args|

        end

      end
    end
  end
end