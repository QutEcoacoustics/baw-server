# frozen_string_literal: true

# Namespace module for API related functionality.
module Api
  # A small module that helps output boilerplate JSON schema definitions.
  # All the declarations here could be inlined with no ill-effect.
  module Schema
    def self.creator_user_stamp
      {
        creator_id: { '$ref' => '#/components/schemas/id', readOnly: true },
        created_at: { type: 'string', format: 'date-time', readOnly: true }
      }
    end

    def self.updater_user_stamp
      {
        updater_id: { '$ref' => '#/components/schemas/nullableId', readOnly: true },
        updated_at: { type: ['null', 'string'], format: 'date-time', readOnly: true }
      }
    end

    def self.deleter_user_stamp
      {
        deleter_id: { '$ref' => '#/components/schemas/nullableId', readOnly: true },
        deleted_at: { type: ['null', 'string'], format: 'date-time', readOnly: true }
      }
    end

    def self.all_user_stamps
      {
        **creator_user_stamp,
        **updater_user_stamp,
        **deleter_user_stamp
      }
    end

    def self.updater_and_creator_user_stamps
      {
        **creator_user_stamp,
        **updater_user_stamp
      }
    end

    def self.creator_and_deleter_user_stamps
      {
        **creator_user_stamp,
        **deleter_user_stamp
      }
    end

    def self.rendered_markdown(attr)
      {
        "#{attr}": { type: ['string', 'null'] },
        "#{attr}_html": { type: ['string', 'null'], readOnly: true },
        "#{attr}_html_tagline": { type: ['string', 'null'], readOnly: true }
      }
    end

    def self.timezone_information
      { '$ref' => '#/components/schemas/timezone_information' }
    end

    def self.image_urls
      { '$ref' => '#/components/schemas/image_urls' }
    end

    def self.permission_levels
      { '$ref' => '#/components/schemas/permission_levels' }
    end
  end
end
