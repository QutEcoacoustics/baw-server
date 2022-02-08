# frozen_string_literal: true

module RailsSemanticLogger
  module ActiveRecord
    class LogSubscriber
      # def self.prepended(target)
      #   target.instance_eval do
      alias bind_values bind_values_v6_1
      alias render_bind render_bind_v6_1
      alias type_casted_binds type_casted_binds_v5_1_5
      #   end
      # end
    end
  end
end

if Gem.loaded_specs['rails_semantic_logger'].version > Gem::Version.new('4.10.0')
  raise "remove #{__FILE__} patch if https://github.com/reidmorrison/rails_semantic_logger/issues/156 resolved"
end
