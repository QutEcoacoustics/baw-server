# frozen_string_literal: true

describe BawWorkers::BatchAnalysis::CommandTemplater do
  it 'complains if you use an an invalid placeholder' do
    expect {
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'test {{invalid}} placeholder {{output_dir}} {{source}}',
        {}
      )
    }.to raise_error(
      ArgumentError,
      'Unknown placeholder `invalid` in command'
    )
  end

  it 'complains if a placeholder is not in the options hash' do
    expect {
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'test {{source}} placeholder {{output_dir}}',
        {}
      )
    }.to raise_error(
      ArgumentError,
      'Missing key in values for placeholder `source`'
    )
  end

  it 'does not complain if a placeholders value is nil' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test {{source}} placeholder {{output_dir}}',
      { source: nil, output_dir: nil }
    )

    command.should eq('test  placeholder ')
  end

  it 'complains in a required placeholder was not used' do
    expect {
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'test {{id}} placeholder',
        { id: 1234 }
      )
    }.to raise_error(
      ArgumentError,
      'Missing required placeholders in command: `source_dir` or `source`'
    )
  end

  it 'can print Time as an ISO8601 string' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test "{{source}}" "{{output_dir}}"',
      {
        source: Time.new(2018, 1, 1, 12, 0, 0, '+10:00'),
        output_dir: 'output_dir'
      }
    )

    expect(command).to eq('test "2018-01-01T12:00:00+10:00" "output_dir"')
  end

  it 'can print ActiveSupport::TimeWithZone as iso8601 string' do
    time = Time.zone.local(2018, 1, 1, 12, 0, 0)
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test "{{source}}" "{{output_dir}}"',
      {
        source: time,
        output_dir: 'output_dir'
      }
    )

    expect(command).to eq("test \"#{time.iso8601}\" \"output_dir\"")
  end

  it 'can still customize a Time value with filters' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test "{{source | date: \'%Y-%m-%d\'}}" placeholder {{output_dir}}',
      {
        source: Time.new(2018, 1, 1, 12, 0, 0, '+10:00'),
        output_dir: 'output_dir'
      }
    )
    expect(command).to eq('test "2018-01-01" placeholder output_dir')
  end

  it 'can template multiple placeholders' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'test "{{source}}" placeholder "{{config}}" "{{source}}" "{{config}}" "{{output_dir}}"',
      {
        source: 'source',
        config: 'config',
        output_dir: 'output_dir'
      }
    )

    expect(command).to eq('test "source" placeholder "config" "source" "config" "output_dir"')
  end

  it 'can template all other placeholders' do
    template = <<~BASH
      {{source_dir}}
      {{config_dir}}
      {{output_dir}}
      {{temp_dir}}
      {{source_basename}}
      {{config_basename}}
      {{source}}
      {{config}}
      {{latitude}}
      {{longitude}}
      {{timestamp}}
      {{id}}
      {{uuid}}
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

  it 'can template a literal curly brace' do
    command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
      'echo {0..10} | xargs -n1 -I{} echo "test {{ \'{{\' }} {{source}} {{ output_dir }} placeholder {}"',
      { source: 'abc', output_dir: 'output_dir' }
    )

    command.should eq('echo {0..10} | xargs -n1 -I{} echo "test {{ abc output_dir placeholder {}"')
  end

  describe 'supports basic if/else for templating' do
    let(:template) {
      <<~COMMAND.squish
        test {{source}} placeholder {%if latitude%} --lat {{latitude}}{%endif%}#{' '}
        {%if config%}--config "/some/path:{{config}}"{% endif %}#{' '}
        {%if output_dir%}--output "{{output_dir}}"{%else%}--output "default"{%endif%}
      COMMAND
    }

    it 'treat nil values as false' do
      command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        template,
        {
          source: 'source',
          latitude: nil,
          config: nil,
          output_dir: nil
        }
      )

      expect(command).to eq('test source placeholder   --output "default"')
    end

    it 'does not allow missing keys as false' do
      expect {
        BawWorkers::BatchAnalysis::CommandTemplater.format_command(
          template,
          {
            source: 'source'
          }
        )
      }.to raise_error(ArgumentError, 'Missing key in values for placeholder `latitude`')
    end

    it 'includes the if block if the value is present' do
      command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        template,
        {
          source: 'source',
          latitude: 123,
          config: 'config',
          output_dir: 'output_dir'
        }
      )

      expect(command).to eq('test source placeholder  --lat 123 --config "/some/path:config" --output "output_dir"')
    end

    it 'does not require keys for placeholders in branches that are not rendered' do
      command = BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        'run {{source}} {%if config%} --config {{config}}{%endif%} {%if output_dir%}--output {{output_dir}}{%else%}--output default{%endif%}',
        {
          source: 'source',
          config: nil,
          output_dir: nil
        }
      )

      expect(command).to eq('run source  --output default')
    end

    it 'rejects invalid placeholders in if conditions' do
      expect {
        BawWorkers::BatchAnalysis::CommandTemplater.format_command(
          'run {{source}} {%if nope%}x{%endif%} --output {{output_dir}}',
          { source: 'source', output_dir: 'out' }
        )
      }.to raise_error(ArgumentError, 'Unknown placeholder `nope` in command')
    end

    it 'rejects invalid commands' do
      expect {
        BawWorkers::BatchAnalysis::CommandTemplater.format_command(
          'run {{source}} {%donkey source%}one{%else%}three{%endif%}',
          { source: 'source' }
        )
      }.to raise_error(ArgumentError, /Liquid syntax error: Unknown tag 'donkey'/)
    end

    [
      'test {{source}} placeholder {%if latitude%} --lat {{latitude}}{%endif',
      'test {{source}} placeholder {%if latitude%} --lat {{latitude}}',
      'test {{source}} placeholder --lat {{latitude}}{%endif%}',
      'test {{source}} placeholder {%else%} --lat {{latitude}}{%endif%'
    ].each do |invalid_template|
      it 'rejects invalid if/else syntax' do
        expect {
          BawWorkers::BatchAnalysis::CommandTemplater.format_command(
            invalid_template,
            {
              source: 'source',
              latitude: 123
            }
          )
        }.to raise_error(ArgumentError, /Liquid syntax error/)
      end
    end
  end
end
