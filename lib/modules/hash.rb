# http://qugstart.com/blog/uncategorized/ruby-multi-level-nested-hash-value/
# user_hash.hash_val(:extra, :birthday, :year) => 1951
class ::Hash

  # http://stackoverflow.com/a/9381776
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end

  # http://stackoverflow.com/questions/1753336/hashkey-to-hash-key-in-ruby
  def method_missing(method, *opts)
    m = method.to_s
    if self.has_key?(m)
      return self[m]
    elsif self.has_key?(m.to_sym)
      return self[m.to_sym]
    end
    super
  end
end