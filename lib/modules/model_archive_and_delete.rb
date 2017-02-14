module ModelArchiveAndDelete
    extend ActiveSupport::Concern

    included do
      # add deleted_at and deleter_id
      acts_as_paranoid
      validates_as_paranoid
    end

    def self.archive_only?
      false
    end
end