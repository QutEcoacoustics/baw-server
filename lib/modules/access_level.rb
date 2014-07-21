class AccessLevel
  UNKNOWN = 1
  NONE = 2
  READ = 4
  WRITE = 8
  OWNER = 16
  ADMIN = 32

  def self.value_to_name(value)
    case value
      when AccessLevel::ADMIN
        'Admin'
      when AccessLevel::OWNER
        'Owner'
      when AccessLevel::WRITE
        'Write'
      when AccessLevel::READ
        'Read'
      when AccessLevel::NONE
        'None'
      when AccessLevel::UNKNOWN
        'Unknown'
      else
        'Unknown'
    end
  end
end