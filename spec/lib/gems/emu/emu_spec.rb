# frozen_string_literal: true

describe Emu do
  it 'can return the version of the EMU executable' do
    actual = Emu.version

    expect(actual).to eq(`/emu/emu --version`.chomp)
  end

  context 'when fixing' do
    let(:target) {
      path = temp_file
      FileUtils.copy(Fixtures.bar_lt_faulty_duration, path)
      path
    }

    it 'can check if a fix is needed' do
      actual = Emu::Fix.check(target, Emu::Fix::FL_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(2.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Affected',
            severity: 'Moderate',
            message: "File's duration is wrong",
            data: {
              firmware: {
                comment: 'SensorFirmwareVersion= 3.20                                 ',
                version: 3.2,
                found_at: '[207, 267)',
                tags: []
              },
              header_samples: 317_292_544,
              counted_samples: 158_646_272
            }
          }
        }
      )
    end

    it 'can apply a fix' do
      actual = Emu::Fix.apply(target, Emu::Fix::FL_DURATION_BUG)

      expect(actual.records.first).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(2.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Fixed',
            check_result: an_instance_of(ActiveSupport::HashWithIndifferentAccess),
            message: 'Old total samples was 317292544, new total samples is: 158646272',
            new_path: nil
          }
        },
        backup_file: nil
      )
    end

    it 'can apply multiple fixes' do
      actual = Emu::Fix.apply(target, Emu::Fix::FL_DURATION_BUG, Emu::Fix::FL_PREALLOCATED_HEADER)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        # flaky test - goes slower when running with other tests
        time_taken: a_value_within(2.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Fixed',
            check_result: an_instance_of(ActiveSupport::HashWithIndifferentAccess),
            message: 'Old total samples was 317292544, new total samples is: 158646272',
            new_path: nil
          },
          'FL001' => {
            status: 'NoOperation',
            check_result: an_instance_of(ActiveSupport::HashWithIndifferentAccess),
            message: nil,
            new_path: nil
          }
        },
        backup_file: nil
      )
    end

    it 'checks each fix is idempotent' do
      # fix once, discard the result
      _ = Emu::Fix.apply(target, Emu::Fix::FL_DURATION_BUG)

      last_write = target.mtime

      # attempt to fix again - no change should occur
      actual = Emu::Fix.apply(target, Emu::Fix::FL_DURATION_BUG)

      expect(target.mtime).to eq last_write

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(2.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'NoOperation',
            check_result: a_hash_including(
              status: 'Repaired',
              severity: 'None',
              data: a_hash_including(
                firmware: a_hash_including(
                  tags: ['EMU+FL010']
                )
              ),
              message: "File has already had it's duration repaired"
            ),
            message: nil,
            new_path: nil
          }
        },
        backup_file: nil
      )
    end

    it 'has a fix if needed function' do
      actual = Emu::Fix.fix_if_needed(target, Emu::Fix::FL_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(2.0).of(3)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Fixed',
            check_result: an_instance_of(ActiveSupport::HashWithIndifferentAccess),
            message: 'Old total samples was 317292544, new total samples is: 158646272',
            new_path: nil
          }
        },
        backup_file: nil
      )
    end

    it 'has a fix if needed function (case: not needed)' do
      # fix once, discard the result
      _ = Emu::Fix.apply(target, Emu::Fix::FL_DURATION_BUG)
      actual = Emu::Fix.fix_if_needed(target, Emu::Fix::FL_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(2.0).of(3)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Repaired',
            message: "File has already had it's duration repaired",
            severity: 'None',
            data: a_hash_including(
              firmware: a_hash_including(
                tags: ['EMU+FL010']
              )
            )
          }
        }
      )
    end
  end

  context 'when extracting metadata' do
    it 'can extract metadata' do
      path = Fixtures.bar_lt_file

      actual = Emu::Metadata.extract(path)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(1.0).of(3.5)
      )

      expect(actual).to be_an_instance_of(Array).and(include(
        a_hash_including(
          'calculated_checksum' => {
            'type' => 'SHA256',
            'value' => '3bb32933cd8b9139bea325ef256f07afc4fb4ed53e6a1982dd85947afebce1dd'
          },
          'duration_seconds' => 14_389.684535147392290249433106,
          'start_date' => '2020-08-01T00:00:00+10:00',
          'local_start_date' => '2020-08-01T00:00:00'
        )
      ))
    end
  end

  context 'when listing fixes' do
    it 'can list fixes' do
      actual = Emu::Fix.list

      expect(actual).to be_an_instance_of(Array).and(include(
        a_hash_including(
          problem: 'FL010',
          fixable: true,
          safe: true
        )
      ))
    end
  end

  it 'can handle bad exit codes' do
    file = temp_file
    file.touch
    actual = Emu::Fix.apply(file, 'invalidfix')

    expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
      success: false,
      log: a_string_including('Unhandled exception'),
      records: an_instance_of(Array)
    )
  end
end
