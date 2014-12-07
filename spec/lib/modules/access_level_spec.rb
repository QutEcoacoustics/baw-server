require 'spec_helper'

describe AccessLevel do

  context 'decomposes to the correct levels' do
    it 'from none' do
      result = AccessLevel.decompose(:none)
      expect(result).to eq([:none])
    end

    it 'from reader' do
      result = AccessLevel.decompose(:reader)
      expect(result).to eq([:reader])
    end

    it 'from writer' do
      result = AccessLevel.decompose(:writer)
      expect(result).to eq([:reader, :writer])
    end

    it 'from owner' do
      result = AccessLevel.decompose(:owner)
      expect(result).to eq([:reader, :writer, :owner])
    end

  end

  it 'errors when decomposing an invalid value' do
    expect {
    AccessLevel.decompose(:blah_blah)
    }.to raise_error(ArgumentError, /Access level 'blah_blah' is not in available levels/)
  end
end