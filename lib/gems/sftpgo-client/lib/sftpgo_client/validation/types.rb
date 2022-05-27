# frozen_string_literal: true

require 'ipaddr'

module SftpgoClient
  module Types
    include Dry.Types()
    include Dry::Logic

    ID = Strict::Integer.constrained(gteq: 0)
    NATURAL = Strict::Integer.constrained(gteq: 0)
    UINT32 = Strict::Integer.constrained(gteq: 0, lteq: 65_535)

    IPAddr = Types.Constructor(::IPAddr)
    Pathname = Constructor(::Pathname)
  end
end
