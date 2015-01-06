namespace :baw do
namespace :api_docs do

  desc 'Generate API docs'
  task :generate do
    run_locally do
      system 'time bin/rake docs:generate GENERATE_DOC=true'
    end
  end

  desc 'Upload API docs'
  task :upload do
    on release_roles :all do
      # upload the folder and contents at './doc/api' to "#{shared_path}/doc".
      # the 'api' folder will end up in the /doc folder.
      upload! './doc/api', "#{shared_path}/doc", recursive: true
    end
  end
end
  end