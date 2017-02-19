module ModelArchiveAndDelete
    extend ActiveSupport::Concern

    included do
      # enable archiving
      acts_as_paranoid
      validates_as_paranoid
    end

    def self.archive_only?
      false
    end
end