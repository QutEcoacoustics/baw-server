# frozen_string_literal: true

describe Emu do
  it 'can return the version of the EMU executable' do
    actual = Emu.version

    expect(actual).to eq(`/emu/emu --version`.chomp)
  end

  context 'when fixing' do
    include TempFileHelpers::ExampleGroup

    let(:target) {
      path = temp_file
      FileUtils.copy(Fixtures.bar_lt_faulty_duration, path)
      path
    }

    it 'can check if a fix is needed' do
      actual = Emu::Fix.check(target, Emu::Fix::BAR_LT_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(1.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Affected',
            severity: 'Moderate',
            message: "File's duration is wrong",
            data: {
              comment: 'SensorFirmwareVersion= 3.20                                 ',
              version: 3.2,
              found_at: '[207, 267)',
              tags: []
            }
          }
        }
      )
    end

    it 'can apply a fix' do
      actual = Emu::Fix.apply(target, Emu::Fix::BAR_LT_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(1.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Fixed',
            check_result: an_instance_of(HashWithIndifferentAccess),
            message: 'Old total samples was 317292544, new total samples is: 158646272'
          }
        }
      )
    end

    it 'checks each fix is idempotent' do
      # fix once, discard the result
      _ = Emu::Fix.apply(target, Emu::Fix::BAR_LT_DURATION_BUG)

      last_write = target.mtime

      # attempt to fix again - no change should occur
      actual = Emu::Fix.apply(target, Emu::Fix::BAR_LT_DURATION_BUG)

      expect(target.mtime).to eq last_write

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(1.0).of(1.5)
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
                tags: ['EMU+FL010']
              )
            ),
            message: "File has already had it's duration repaired"
          }
        }
      )
    end

    it 'has a fix if needed function' do
      actual = Emu::Fix.fix_if_needed(target, Emu::Fix::BAR_LT_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(1.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Fixed',
            check_result: an_instance_of(HashWithIndifferentAccess),
            message: 'Old total samples was 317292544, new total samples is: 158646272'
          }
        }
      )
    end

    it 'has a fix if needed function (case: not needed)' do
      # fix once, discard the result
      _ = Emu::Fix.apply(target, Emu::Fix::BAR_LT_DURATION_BUG)
      actual = Emu::Fix.fix_if_needed(target, Emu::Fix::BAR_LT_DURATION_BUG)

      expect(actual).to be_an_instance_of(Emu::ExecuteResult).and having_attributes(
        success: true,
        log: "\n",
        records: an_instance_of(Array),
        time_taken: a_value_within(1.0).of(1.5)
      )

      expect(actual.records.first).to match(
        file: target.to_s,
        problems: {
          'FL010' => {
            status: 'Repaired',
            message: "File has already had it's duration repaired",
            severity: 'None',
            data: a_hash_including(
              tags: ['EMU+FL010']
            )
          }
        }
      )
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
end
