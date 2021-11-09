# frozen_string_literal: true

module Api
  module Schema
    # A small module that helps output boilerplate JSON schema definitions.
    # All the declarations here could be inlined with no ill-effect.
    module Helpers
      def id(nullable: false, read_only: true)
        { '$ref' => nullable ? '#/components/schemas/nullableId' : '#/components/schemas/id', readOnly: read_only }
      end

      def ids(nullable: false, read_only: false)
        { type: nullable ? ['null', 'array'] : 'array', items: id, readOnly: read_only }
      end

      def date(nullable: false, read_only: false)
        { type: nullable ? ['null', 'string'] : 'string', format: 'date-time', readOnly: read_only }
      end

      def uuid
        { type: 'string', format: 'uuid', readOnly: true }
      end

      def creator_user_stamp
        {
          creator_id: id,
          created_at: date(read_only: true)
        }
      end

      def updater_user_stamp
        {
          updater_id: id(nullable: true),
          updated_at: date(nullable: true, read_only: true)
        }
      end

      def deleter_user_stamp
        {
          deleter_id: id(nullable: true),
          deleted_at: date(nullable: true, read_only: true)
        }
      end

      def all_user_stamps
        {
          **creator_user_stamp,
          **updater_user_stamp,
          **deleter_user_stamp
        }
      end

      def updater_and_creator_user_stamps
        {
          **creator_user_stamp,
          **updater_user_stamp
        }
      end

      def creator_and_deleter_user_stamps
        {
          **creator_user_stamp,
          **deleter_user_stamp
        }
      end

      def rendered_markdown(attr)
        {
          "#{attr}": { type: ['string', 'null'] },
          "#{attr}_html": { type: ['string', 'null'], readOnly: true },
          "#{attr}_html_tagline": { type: ['string', 'null'], readOnly: true }
        }
      end

      def timezone_information
        { '$ref' => '#/components/schemas/timezone_information' }
      end

      def image_urls
        { '$ref' => '#/components/schemas/image_urls' }
      end

      def permission_levels
        { '$ref' => '#/components/schemas/permission_levels' }
      end
    end
  end
end
