# frozen_string_literal: true

# from http://stackoverflow.com/questions/4078906/is-there-a-natural-sort-by-method-for-ruby/15170063#15170063
class NaturalSort
  def self.sort(collection, property)
    collection.sort_by { |e| e.send(property.to_sym).split(/(\d+)/).map { |a| a =~ /\d+/ ? a.to_i : a } }
  end
end
