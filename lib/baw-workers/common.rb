module BawWorkers
  # Common functionality.
  class Common

    # def self.stringify_hash(hash)
    #   s2s =
    #       lambda do |h|
    #         if Hash === h
    #           Hash[
    #               h.map do |k, v|
    #                 [
    #                     k.is_a?(Symbol) ? k.to_s : k,
    #                     s2s[v.is_a?(Symbol) ? v.to_s : v]
    #                 ]
    #               end
    #           ]
    #         elsif Array === h
    #           h.map { |item| item.is_a?(Symbol) ? item.to_s : item }
    #         else
    #           h
    #         end
    #       end
    #
    #   s2s[hash]
    # end

  end
end