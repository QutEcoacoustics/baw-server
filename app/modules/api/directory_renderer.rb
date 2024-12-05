# frozen_string_literal: true

module Api
  # Sends file blobs or directory listings.
  module DirectoryRenderer
    # @param [FileSystems::Structs::DirectoryWrapper, FileSystems::Structs::FileWrapper] result
    def send_filesystems_result(result, opts)
      if result.is_a?(FileSystems::Structs::DirectoryWrapper)
        send_filesystems_directory(result, opts)
      elsif result.is_a?(FileSystems::Structs::FileWrapper)
        send_filesystems_file(result)
      else
        raise CustomErrors::UnprocessableEntityError, 'Invalid result type.'
      end
    end

    # @param [FileSystems::Structs::DirectoryWrapper] result
    def send_filesystems_directory(result, opts = {})
      wrapped = result.to_h.except(:total_count)

      opts[:total] = result.total_count
      render_format(wrapped, opts)
    end

    # @param [FileSystems::Structs::FileWrapper] result
    def send_filesystems_file(result)
      result => { io:, name: filename, mime: type, size:, modified: }
      disposition = 'attachment'

      response.headers['Cache-Control'] = 'no-cache'
      # This disables the etag middleware - improves speed and memory pressure
      # by avoiding a double read of the file.
      response.headers['Last-Modified'] = modified.httpdate.to_s
      response.headers['X-Accel-Buffering'] = 'no'

      if request.head?
        headers['Content-Length'] = size.to_s if size
        send_file_headers!({ filename:, type:, disposition: })
        head :ok
      elsif result.io.is_a?(File)
        # It's a real file on disk, use x-sendfile for most efficient transmission
        send_file(result.physical_paths.first, { filename:, type:, disposition: })
      else
        # Any other stream - remote or abstract (like a zip file entry)
        # we need to stream it manually
        send_io(result.io, filename:, type:, disposition:, size:)
      end
    rescue StandardError
      # ensure we close the IO if an error occurs
      result.io.close
      raise
    end

    # use send_data only supports sending whole bodies
    # So we stream manually.
    # There's an ActionController::Live module that can be used to stream responses
    # but it deletes the content-length header and has other undesirable side effects
    # - like multi threaded responses that mess with devise.
    # @param io [IO] any IO like object
    # @param filename [String] the name of the file to suggest to the client
    # @param type [String,Symbol] the mime type of the file
    # @param disposition [String] either 'attachment' or 'inline'
    def send_io(io, filename:, type:, disposition:, size:)
      send_file_headers!({ filename: filename, type: type, disposition: disposition })
      headers['Content-Length'] = size.to_s if size

      self.response_body = StreamingResponseBody.new(io)
    end

    # send back data from an IO without buffering into memory
    # only works if etag middleware does not activate
    class StreamingResponseBody
      def initialize(io)
        @io = io
      end

      def each
        return enum_for(:each) unless block_given?

        #i = 0
        @io.rewind
        while (chunk = @io.read(16_384))
          #Rails.logger.debug('Sending chunk',{ chunk_size: chunk.size, index: i, stream_position: @io.pos })
          yield chunk
          #i += 1
        end

        @io.close
      end
    end
  end
end
