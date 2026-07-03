# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Generate automatic + merge extra
      # TODO: all project owners should be something in the array, and all tagging creators should be as well
      # ('contributor') - even verification creators, plus optional add more in from param
      # Should be able to have a list of users and we can map a user to a contributor descriptor
      # TODO: but we only have user_names, not real names, i'll need to check this.
      class Descriptor::Contributor < Descriptor
        attribute :title, Types::String # name/title of the person or organisation
        attribute :role, Types::Role

        attribute? :email, Types::String.optional
        attribute? :path, Types::String.optional
        attribute? :organization, Types::String.optional
      end
    end
  end
end
