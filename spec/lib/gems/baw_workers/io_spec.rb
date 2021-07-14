# frozen_string_literal: true

describe BawWorkers::IO do
  it 'can allocate a binary string' do
    buffer = BawWorkers::IO.new_binary_string(capacity: 1024)

    expect(buffer.encoding).to eq Encoding::ASCII_8BIT
    expect(buffer.size).to eq 0
    # there is buffer + other structural bytes
    expect(ObjectSpace.memsize_of(buffer)).to eq 1024 + 41
    expect(buffer.frozen?).to eq false
  end

  it 'can write to a binary buffer' do
    buffer = BawWorkers::IO.write_binary_buffer { |io|
      io.write(File.binread(Fixtures.audio_file_mono))
    }

    expect(buffer).to be_an_instance_of(StringIO)
    expect(buffer.external_encoding).to eq Encoding::ASCII_8BIT
    expect(buffer.internal_encoding).to eq nil
    expect(buffer.closed?).to eq false
    expect(buffer.size).to eq Fixtures.audio_file_mono.size
    expect(buffer.string).to eq File.binread(Fixtures.audio_file_mono)
  end

  it 'can hash an IO' do
    path = Fixtures.audio_file_stereo
    expected = '3beb899a6ae84030afe7f4a47dbaa73fa2506c6c371e670a12eac107a1205bff'

    hash_file = BawWorkers::Config.file_info.generate_hash(path).hexdigest
    hash_io = BawWorkers::IO.hash_sha256_io(File.open(path, 'rb'))
    hash_string_io = BawWorkers::IO.hash_sha256_io(StringIO.new(File.binread(path)))

    bytes = File.binread(path)
    buffer = BawWorkers::IO.write_binary_buffer { |io|
      io << (bytes)
    }
    hash_buffer = BawWorkers::IO.hash_sha256_io(buffer)

    aggregate_failures do
      expect(hash_file).to eq expected
      expect(hash_io).to eq expected
      expect(hash_string_io).to eq expected

      expect(buffer.external_encoding.name).to eq Encoding::ASCII_8BIT.name
      expect(bytes.encoding).to eq Encoding::ASCII_8BIT
      expect(hash_buffer).to eq expected
    end
  end
end
