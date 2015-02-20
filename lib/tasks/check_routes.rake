# run using rake baw:routes:check
namespace :baw do
  namespace :routes do

    desc 'Check that controller actions and routes match.'
    task :check => :environment do

      # require all controllers
      Dir["#{Rails.root}/app/controllers/*.rb"].each {|file| require file }

      # gather expected controllers and actions
      existing_controllers = []

      # list all controllers
      controllers = ::ApplicationController.descendants

      controllers.each do |controller|
        # get only public methods that are defined in this class
        # these are expected to be actions
        controller.action_methods.each do |public_method|

          existing_controllers.push(
              {
                  controller: controller.name,
                  action: public_method.to_s
              }
          ) unless public_method.to_s.starts_with?('_callback_')
        end
      end

      #puts existing_controllers

      existing_routes = []

      # get all routes
      Rails.application.routes.routes.map do |route|
        route_info = {alias: route.name, path: route.path.spec.to_s, controller: route.defaults[:controller], action: route.defaults[:action]}

        if !route_info[:controller].blank?
          existing_routes.push(
              {
                  controller: "#{route_info[:controller]}_controller".camelize.constantize.new.class.name,
                  action: route_info[:action].blank? ? '' : route_info[:action].to_s
              }
          )
        end
      end

      # compare existing_controllers with existing_routes

      #puts existing_routes

      puts '---- existing_routes not in existing_controllers'
      puts existing_routes - existing_controllers
      puts ''
      puts '---- existing_controllers not in existing_routes'
      puts existing_controllers - existing_routes

    end
  end
end

