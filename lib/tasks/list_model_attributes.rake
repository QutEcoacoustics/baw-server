# run using bin/rake baw:models:list
namespace :baw do
  namespace :models do
    desc 'List all models with their attributes.'
    task list: :environment do
      Rails.application.eager_load!
      sep_char = '-'
      ActiveRecord::Base.descendants.each do |model|
        model_name = model.name
        title = "#{sep_char*3}#{model_name}#{sep_char*3}"
        puts title
        puts model.attribute_names.join(', ')
        puts
      end
    end


  end
end