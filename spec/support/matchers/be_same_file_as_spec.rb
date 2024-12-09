# frozen_string_literal: true

describe :be_same_file_as do
  before do
    @temp_file = temp_file
  end

  def combine_regexes(*regexes)
    regexes.map { |r| a_string_matching(r) }.reduce(:and)
  end

  it 'passes' do
    a = temp_file
    b = temp_file

    a.write('a')
    b.write('a')

    expect(a).to be_same_file_as(b)
  end

  it 'can produces a good error message on failure' do
    a = temp_file
    b = temp_file

    a.write("#{'a' * 20}b#{'a' * 20}")
    b.write('a' * 41)

    expect {
      expect(a).to be_same_file_as(b)
    }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      combine_regexes(
        /Files differ at byte\(s\):/,
        #-->        20     "b" != "a"
        /-->        20     "b" != "a"/
      )
    )
  end

  it 'can negative match' do
    a = temp_file
    b = temp_file

    a.write("#{'a' * 20}b#{'a' * 20}")
    b.write('a' * 41)

    expect(a).not_to be_same_file_as(b)
  end

  it 'produces a good error message on negative match failure' do
    a = temp_file
    b = temp_file

    a.write('a')
    b.write('a')

    expect {
      expect(a).not_to be_same_file_as(b)
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /not to be the same file as/)
  end

  it 'works on IO objects' do
    a = temp_file
    b = temp_file

    a.write('a')
    b.write('a')

    expect(a.open).to be_same_file_as(b.open)
  end

  it 'works on different size objects' do
    a = temp_file
    b = temp_file

    a.write('a' * 20)
    b.write('a' * 21)

    expect {
      expect(a).to be_same_file_as(b)
    }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      combine_regexes(
        /Files differ at byte\(s\):/,
        /           19     "a" == "a"/,
        /-->        20   <EOF> != "a"/,
        /           21   <EOF> == <EOF>/
      )
    )
  end

  it 'produces a good error message on small files' do
    a = temp_file
    b = temp_file

    a.write('a')
    b.write('b')

    expect {
      expect(a).to be_same_file_as(b)
    }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      combine_regexes(
        /Files differ at byte\(s\):/,
        /-->         0     "a" != "b"/
      )
    )
  end

  it 'produces a good error message on large files' do
    # larger than the buffer at least
    a = temp_file
    b = temp_file

    a.write('a' * 32_768)
    b.write('a' * 32_768)
    s = b.open('r+')
    s.seek(20_000)
    s.write("\0")
    s.write('123')
    s.close

    expect {
      expect(a).to be_same_file_as(b)
    }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      combine_regexes(
        /Files differ at byte\(s\):/,
        #-->     20000     "a" != "\x00"
        /-->     20000     "a" != "\\x00"/,
        /        20001     "a" != "1"/,
        /        20002     "a" != "2"/,
        /        20003     "a" != "3"/,
        /        20004     "a" == "a"/
      )
    )
  end
end
