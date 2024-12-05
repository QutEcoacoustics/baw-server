# frozen_string_literal: true

ByteMatch = Data.define(:offset, :match, :actual, :expected)

RSpec::Matchers.define(:be_same_file_as) do |expected_file_path_or_io|
  match do |actual_file_path_or_io|
    @expected_io = open_io_or_path(expected_file_path_or_io)
    @actual_io = open_io_or_path(actual_file_path_or_io)

    @results = bytes_match(@actual_io, @expected_io)

    @results.empty?
  end

  failure_message do |actual_file_path_or_io|
    msg = ''
    unless @results.empty?
      msg = "Files differ at byte(s):\n\n"
      msg += "       offset  actual    expected \n"
      msg += "       ------  ------    -------- \n"
      msg += @results.map { |result|
        symbol = result.match == :mismatch ? '-->' : '   '

        equal = result.actual == result.expected ? '==' : '!='
        a = result.actual == :eof ? '<EOF>' : result.actual.chr.dump
        e = result.expected == :eof ? '<EOF>' : result.expected.chr.dump

        "#{symbol} #{result.offset.to_s.rjust(9)} #{a.rjust(7)} #{equal} #{e.ljust(7)}"
      }.join("\n")

      msg += "\n\n"
      msg += "actual size: #{@actual_io.size}\n"
      msg += "expected size: #{@expected_io.size}\n"
    end

    "expected that #{actual_file_path_or_io} would be the same as #{expected_file_path_or_io} but differences were found: " + msg
  end

  description do
    "be the same file as #{expected_file_path_or_io}"
  end

  def bytes_match(actual_io, expected_io)
    results = []
    offset = 0
    while (actual_chunk = actual_io.read(16_384))
      expected_chunk = expected_io.read(actual_chunk.size)

      mismatch = nil
      0.upto(actual_chunk.size - 1) do |i|
        a = actual_chunk.getbyte(i)
        e = expected_chunk.getbyte(i)

        if a != e
          mismatch = i
          break
        end
      end

      unless mismatch.nil?
        # found a difference, collect samples and stop searching
        results = make_failure_list(offset + mismatch, actual_io, expected_io)
        break
      end

      offset += actual_chunk.size
    end

    # account for different length files but otherwise the same up until this point
    if (actual_io.size != expected_io.size) && results.empty?
      results = make_failure_list([actual_io.size, expected_io.size].min, actual_io, expected_io)
    end

    results
  end

  def make_failure_list(index, actual_io, expected_io)
    ((index - 10)..(index + 10)).filter_map do |i|
      next if i < 0

      match = i == index ? :mismatch : nil

      if i < actual_io.size
        actual_io.seek(i)
        actual_io.read(1)
      else
        :eof
      end => a

      if i < expected_io.size
        expected_io.seek(i)
        expected_io.read(1)
      else
        :eof
      end => e

      ByteMatch.new(i, match, a, e)
    end
  end

  def open_io_or_path(file_path_or_io)
    case file_path_or_io
    in ActionDispatch::TestResponse
      StringIO.new(file_path_or_io.body)
    in String
      raise ArgumentError,
        'Expected a file path, Pathname, ActionDispatch::TestResponse, or IO object but got a String.' \
        'Strings can be ambiguously interpreted as a buffer or a path - use a pathname or a StringIO to disambiguate.'
    in Pathname
      file_path_or_io.open
    # when the object as a #read method
    in Object if file_path_or_io.respond_to?(:read)
      file_path_or_io
    else
      raise ArgumentError, "Expected a file path, Pathname or IO object, got #{file_path_or_io.class}"
    end
  end
end
