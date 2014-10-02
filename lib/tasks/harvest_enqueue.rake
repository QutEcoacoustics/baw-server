namespace :baw do
  namespace :action do
    desc 'Enqueue files to harvest using Resque'
    task :harvest, [:settings_file, :top_level_dir] => ['worker:init'] do |t, args|

    end
  end
end