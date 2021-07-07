# frozen_string_literal: true

module BawWorkers
  # IO helpers, a particularly for binary string buffers
  module IO
    CAPACITY = 4096

    module_function

    # returns a new mutable string with a binary encoding
    # @param [Integer] capacity the size of the buffer, see String#new
    # @return [String]
    def new_binary_string(capacity: CAPACITY)
      String.new(encoding: Encoding::ASCII_8BIT, capacity: capacity)
    end

    def new_binary_string_io(capacity: CAPACITY)
      StringIO.new(new_binary_string(capacity: capacity), 'wb')
    end

    # yields a writeable StringIO buffer
    # @param [String] buffer if supplied will write to buffer, or else will
    #   allocate a buffer via #new_binary_string
    # @yields [StringIO] the buffer to write to
    # @return [StringIO] an open reader to operate on
    def write_binary_buffer(buffer = nil, &block)
      buffer ||= new_binary_string
      writer = StringIO.new(buffer, 'wb')
      writer.binmode
      begin
        block.call writer if block_given?
      ensure
        writer.close
      end

      StringIO.new(buffer, 'rb')
    end

    # read the bytes of the file and generate a hash
    # will close the IO stream
    # @param [IO] io any IO object
    # @return [String]
    def hash_sha256_io(io)
      unless io_ish?(io)
        raise ArgumentError,
              "io not an IO, it is an #{io.class}"
      end
      raise IOError 'not opened for reading' if io.closed?
      raise ArgumentError 'io must be Encoding::ASCII_8BIT' unless io.external_encoding == Encoding::ASCII_8BIT

      # reopening the stream resets encoding to UTF-8
      #io.reopen if io.closed?
      # might be related to https://bugs.ruby-lang.org/issues/16497

      io.rewind
      io.binmode
      incr_hash = Digest::SHA256.new

      buffer = new_binary_string

      # Read the file CAPACITY bytes at a time
      until io.eof?
        io.read(CAPACITY, buffer)
        incr_hash.update(buffer)
      end

      incr_hash.hexdigest
    ensure
      io.close
    end

    def io_ish?(object)
      return false if nil?

      return true if  object.is_a?(IO) || object.is_a?(StringIO) || object.is_a?(File)

      false
    end
  end
end
