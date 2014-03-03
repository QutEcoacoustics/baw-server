require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_support/core_ext/string/encoding'
require 'arel/visitors/bind_visitor'

# patching:
# "C:\Ruby\lib\ruby\gems\1.9.1\gems\activerecord-3.2.15\lib\active_record\connection_adapters\sqlite_adapter.rb"
## http://stackoverflow.com/questions/5568367/rails-migration-and-column-change
## add this Around line 535 (in version 3.2.9) of
## $GEM_HOME/gems/activerecord-3.2.9/lib/active_record/connection_adapters/sqlite_adapter.rb
## indexes can't be more than 64 chars long
##opts[:name] = opts[:name][0..63]
module ActiveRecord
  module ConnectionAdapters #:nodoc:

    # The SQLite adapter works with both the 2.x and 3.x series of SQLite with the sqlite-ruby
    # drivers (available both as gems and from http://rubyforge.org/projects/sqlite-ruby/).
    #
    # Options:
    #
    # * <tt>:database</tt> - Path to the database file.
    class SQLiteAdapter < AbstractAdapter

      protected


      def copy_table_indexes(from, to, rename = {}) #:nodoc:
        indexes(from).each do |index|
          name = index.name
          if to == "altered_#{from}"
            name = "temp_#{name}"
          elsif from == "altered_#{to}"
            name = name[5..-1]
          end

          to_column_names = columns(to).map { |c| c.name }
          columns = index.columns.map { |c| rename[c] || c }.select do |column|
            to_column_names.include?(column)
          end

          unless columns.empty?
            # index name can't be the same
            opts = {:name => name.gsub(/(^|_)(#{from})_/, "\\1#{to}_")}
            opts[:unique] = true if index.unique
            opts[:name] = opts[:name][0..63] # can't be more than 64 chars long
            add_index(to, columns, opts)
          end
        end
      end
    end
  end
end


# http://blog.choonkeat.com/weblog/2007/02/retrieving-a-se.html
module Mime
  class Type
    class << self
      # Lookup, guesstimate if fail, the file extension
      # for a given mime string. For example:
      #
      # >> Mime::Type.file_extension_of 'text/rss+xml'
      # => "xml"
      def file_extension_of(mime_string)
        set = Mime::LOOKUP[mime_string]
        sym = set.instance_variable_get("@symbol") if set
        return sym.to_s if sym
        return $1 if mime_string =~ /(\w+)$/
      end
    end
  end
end

# http://stackoverflow.com/questions/6128794/rails-json-serialization-of-decimal-adds-quotes
# patch BigDecimal so json is output without quotes.
require 'bigdecimal'

class BigDecimal
  def as_json(options = nil) #:nodoc:
    if finite?
      self
    else
      NilClass::AS_JSON
    end
  end
end

# http://stackoverflow.com/questions/11743835/force-json-serialization-of-numbers-to-specific-precision/11750364#11750364
# enable Float to support specifying the precision when converting to json
require 'active_support/json' # gem install activesupport

class Float
  def as_json(options={})
    if options[:decimals]
      value = round(options[:decimals])
      (i=value.to_i) == value ? i : value
    else
      super
    end
  end
end

# from http://stackoverflow.com/questions/4078906/is-there-a-natural-sort-by-method-for-ruby/15170063#15170063
class NaturalSort
  def self.sort(collection, property)
    collection.sort_by { |e| e.send(property.to_sym).split(/(\d+)/).map { |a| a =~ /\d+/ ? a.to_i : a } }
  end
end

# fix bug in paperclip content_type matcher
module Paperclip
  module Shoulda
    module Matchers
      class ValidateAttachmentContentTypeMatcher
        protected
        def type_allowed?(type)
          @subject.send("#{@attachment_name}_content_type=", type)
          @subject.valid?
          @subject.errors[:"#{@attachment_name}_content_type"].blank? && @subject.errors[:"#{@attachment_name}"].blank?
        end
      end
    end
  end
end


# make sure head requests get the parameters as a query string, not
# in the body
if ENV['RAILS_ENV'] == 'test'
  require 'rspec/core/formatters/base_formatter'
  require 'rack/utils'
  require 'rack/test/utils'

  module RspecApiDocumentation::DSL
    module Endpoint
      def do_request(extra_params = {})
        @extra_params = extra_params

        params_or_body = nil
        path_or_query = path

        if (method == :get || method == :head) && !query_string.blank?
          path_or_query += "?#{query_string}"
        else
          params_or_body = respond_to?(:raw_post) ? raw_post : params
        end

        rspec_api_documentation_client.send(method, path_or_query, params_or_body, headers)
      end
    end
  end

# need to patch json writing to ensure binary response_body
# does not get included.
  module RspecApiDocumentation
    module Writers
      module Formatter

        def self.to_json(object)
          json_obj = object.as_json

          if json_obj.include? :requests
            json_obj.requests.each do |request|
              check_non_ascii_printable = request.response_body =~ /[^[:print:]]/
              unless check_non_ascii_printable.nil?
                request[:response_body] = 'Cannot be printed.'
              end
            end
          end

          JSON.pretty_generate(json_obj)
        end

      end
    end
  end

end

