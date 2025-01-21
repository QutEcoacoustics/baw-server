# frozen_string_literal: true

describe BawWorkers::BatchAnalysis::CommandTemplater do
  it 'complains if you use an an invalid placeholder' do
    expect {
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'test {invalid} placeholder',
        {}
      )
    }.to raise_error(
      ArgumentError,
      'Invalid placeholder `invalid` in command'
    )
  end

  it 'complains if a placeholder is not in the options hash' do
    expect {
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'test {source} placeholder',
        {}
      )
    }.to raise_error(
      ArgumentError,
      'Missing key in values for placeholder `source`'
    )
  end

  it 'does not complain if a placeholders value is nil' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test {source} placeholder {output_dir}',
      { source: nil, output_dir: nil }
    )

    command.should eq('test  placeholder ')
  end

  it 'complains in a required placeholder was not used' do
    expect {
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'test {id} placeholder',
        { id: 1234 }
      )
    }.to raise_error(
      ArgumentError,
      'Missing required placeholders in command: `source_dir` or `source`'
    )
  end

  it 'can template multiple placeholders' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test "{source}" placeholder "{config}" "{source}" "{config}" "{output_dir}"',
      {
        source: 'source',
        config: 'config',
        output_dir: 'output_dir'
      }
    )

    command.should eq('test "source" placeholder "config" "source" "config" "output_dir"')
  end

  it 'can template all other placeholders' do
    template = <<~BASH
      {source_dir}
      {config_dir}
      {output_dir}
      {temp_dir}
      {source_basename}
      {config_basename}
      {source}
      {config}
      {latitude}
      {longitude}
      {timestamp}
      {id}
      {uuid}
    BASH

    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      template,
      {
        source_dir: 'sd',
        config_dir: 'cd',
        output_dir: 'od',
        temp_dir: 'td',
        source_basename: 'sb',
        config_basename: 'cb',
        source: 's',
        config: 'c',
        latitude: 123,
        longitude: 456,
        timestamp: Time.new(2018, 1, 1, 12, 0, 0, '+10:00'),
        id: 789,
        uuid: '0a7f2f46-c715-4c0b-9b54-6ead382c7b17'
      }
    )

    command.should eq(<<~BASH)
      sd
      cd
      od
      td
      sb
      cb
      s
      c
      123
      456
      2018-01-01T12:00:00+10:00
      789
      0a7f2f46-c715-4c0b-9b54-6ead382c7b17
    BASH
  end
end
