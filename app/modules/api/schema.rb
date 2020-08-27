module Api
  module Schema
    def self.all_ids_and_ats
      {
        creator_id: { '$ref' => '#/components/schemas/id', readOnly: true },
        updater_id: { '$ref' => '#/components/schemas/nullableId', readOnly: true },
        deleter_id: { '$ref' => '#/components/schemas/nullableId', readOnly: true },
        created_at: { type: 'date', readOnly: true },
        updated_at: { type: ['null', 'date'], readOnly: true },
        deleted_at: { type: ['null', 'date'], readOnly: true }
      }
    end

    def self.updater_and_creator_ids_and_ats
      {
        creator_id: { '$ref' => '#/components/schemas/id', readOnly: true },
        updater_id: { '$ref' => '#/components/schemas/nullableId', readOnly: true },
        created_at: { type: 'date', readOnly: true },
        updated_at: { type: ['null', 'date'], readOnly: true }
      }
    end

    def self.creator_and_deleter_ids_and_ats
      {
        creator_id: { '$ref' => '#/components/schemas/id', readOnly: true },
        deleter_id: { '$ref' => '#/components/schemas/nullableId', readOnly: true },
        created_at: { type: 'date', readOnly: true },
        deleted_at: { type: ['null', 'date'], readOnly: true }
      }
    end

    def self.creator_ids_and_ats
      {
        creator_id: { '$ref' => '#/components/schemas/id', readOnly: true },
        created_at: { type: 'date', readOnly: true }
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
  end
end
