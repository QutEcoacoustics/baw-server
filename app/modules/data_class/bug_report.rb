# frozen_string_literal: true

module DataClass
  class BugReport
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :name, :email, :date, :description, :content, :recaptcha

    validates_format_of :email, with: /\A[-a-z0-9_+.]+@([-a-z0-9]+\.)+[a-z0-9]{2,4}\z/i, allow_blank: true, allow_nil: true
    validates :date, presence: true, timeliness: { type: :date }
    validates_presence_of :description
    validates_length_of :description, maximum: 2000
    validates_presence_of :content
    validates_length_of :content, maximum: 5000

    def initialize(attributes = {})
      self.date = Time.zone.now.to_formatted_s(:long_year)
      attributes.each do |name, value|
        send("#{name}=", value)
      end
    end

    def persisted?
      false
    end
  end
end
