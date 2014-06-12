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
