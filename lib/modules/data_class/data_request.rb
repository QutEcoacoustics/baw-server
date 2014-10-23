module DataClass
  class DataRequest
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming
    extend Enumerize

    attr_accessor :name, :email, :group, :group_type, :content, :recaptcha

    # enums
    AVAILABLE_GROUP_TYPES_SYMBOLS = [:general, :academic, :government, :non_profit, :commercial, :personal]
    AVAILABLE_GROUP_TYPES = AVAILABLE_GROUP_TYPES_SYMBOLS.map { |item| item.to_s }

    AVAILABLE_GROUP_TYPES_DISPLAY = [
        {id: :general, name: 'General'},
        {id: :academic, name: 'Academic'},
        {id: :government, name: 'Government'},
        {id: :non_profit, name: 'Not-for-profit'},
        {id: :commercial, name: 'Commercial'},
        {id: :personal, name: 'Personal'},
    ]

    enumerize :group_type, in: AVAILABLE_GROUP_TYPES, predicates: true

    validates_presence_of :email
    validates_format_of :email, with: /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, allow_blank: true, allow_nil: true
    validates_presence_of :group
    validates_presence_of :group_type
    validates_presence_of :content
    validates_length_of :content, maximum: 5000

    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end
    end

    def persisted?
      false
    end
  end
end