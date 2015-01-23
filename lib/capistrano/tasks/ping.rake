namespace :baw do
  desc 'Ping application'
  task :ping do
    run_locally do
      system "curl --head #{fetch(:ping_url)}"
    end
  end
end