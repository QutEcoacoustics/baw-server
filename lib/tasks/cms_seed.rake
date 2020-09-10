# frozen_string_literal: true

namespace :baw do
  task import_cms: 'db:seed' do
    puts 'Start importing (custom) CMS seeds!'

    load(Rails.root / 'db' / 'cms_seeds' / 'cms_seeds.rb')

    puts 'Finished importing (custom) CMS seeds!'
  end
end

Rake::Task['db:seed'].enhance do
  Rake::Task['baw:import_cms'].invoke
end
