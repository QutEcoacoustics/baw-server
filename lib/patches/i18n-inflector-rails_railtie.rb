# frozen_string_literal: true

# This patch modifies the railtie and initializer for the i18n-inflector-rails
# gem.
# In rails 6, auto loading constants during initialization is a big no no.
# This patch modifies the initializer so that the necessary includes are
# lazy loaded.
module I18n
  module Inflector
    module Rails
      # inheriting from rails engine causes the app to boot twice, so we can't
      # even open this class as defined in them gem. We have to define it,
      # inconsistently with the gem, and freeze it to prevent modification!
      class Railtie #< ::Rails::Engine
      end.freeze

      class NewRailtie < ::Rails::Railtie
        initializer :before_initialize do
          ActiveSupport.on_load :action_controller do
            ActionController::Base.extend I18n::Inflector::Rails::ClassMethods
            ActionController::Base.include I18n::Inflector::Rails::InstanceMethods
          end
        end

        initializer :after_initialize do
          ActiveSupport.on_load :action_controller do
            ActionController::Base.helper I18n::Inflector::Rails::InflectedTranslate
          end
        end
      end
    end
  end
end

begin
  require 'i18n-inflector-rails'
rescue TypeError => e
  type_error_intercepted = true
  raise e unless e.message.include?('superclass mismatch for class Railtie')
end
#rescue FrozenError => _e
#  freeze_intercepted = true

# the i18n-inflector-rails is slated for removal, when it is, remove this patch
unless defined? I18n::Inflector::InflectionOptions || !type_error_intercepted
  raise 'Cannot find I18n::inflector::Rails, or patch has failed. Remove this patch if the i18n-inflector-rails gem has been removed from the bundle'
end
