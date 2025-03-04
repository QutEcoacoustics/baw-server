# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                                                                                                                   :integer          not null, primary key
#  analysis_identifier(a unique identifier for this script in the analysis system, used in directory names. [-a-z0-0_]) :string           not null
#  description                                                                                                          :string
#  event_import_glob(Glob pattern to match result files that should be imported as audio events)                        :string
#  executable_command                                                                                                   :text             not null
#  executable_settings                                                                                                  :text
#  executable_settings_media_type                                                                                       :string(255)      default("text/plain")
#  executable_settings_name                                                                                             :string
#  name                                                                                                                 :string           not null
#  resources(Resources required by this script in the PBS format.)                                                      :jsonb
#  verified                                                                                                             :boolean          default(FALSE)
#  version(Version of this script - not the version of program the script runs!)                                        :integer          default(1), not null
#  created_at                                                                                                           :datetime         not null
#  creator_id                                                                                                           :integer          not null
#  group_id                                                                                                             :integer
#  provenance_id                                                                                                        :integer
#
# Indexes
#
#  index_scripts_on_creator_id     (creator_id)
#  index_scripts_on_group_id       (group_id)
#  index_scripts_on_provenance_id  (provenance_id)
#
# Foreign Keys
#
#  fk_rails_...           (provenance_id => provenances.id)
#  scripts_creator_id_fk  (creator_id => users.id)
#  scripts_group_id_fk    (group_id => scripts.id)
#
describe Script do
  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:settings_file).
  #                 allowing('text/plain').
  #                 rejecting('text/plain1', 'image/gif', 'image/jpeg', 'image/png', 'text/xml', 'image/abc', 'some_image/png', 'text2/plain') }
  it { is_expected.to belong_to(:creator) }

  it 'has a valid factory' do
    script = create(:script)

    expect(script).to be_valid
  end

  it { is_expected.to have_many(:analysis_jobs) }

  it 'validates the existence of a creator' do
    expect(build(:script, creator_id: nil)).not_to be_valid
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:executable_command) }

  it { is_expected.to validate_length_of(:name).is_at_least(2) }
  it { is_expected.to validate_length_of(:analysis_identifier).is_at_least(2).is_at_most(255) }
  it { is_expected.to validate_length_of(:executable_command).is_at_least(2) }

  describe 'settings' do
    it 'validates that if settings name is nil, then settings and media type is also nil' do
      script = build(:script, executable_settings_name: nil, executable_settings_media_type: nil,
        executable_settings: 'some settings')
      expect(script).not_to be_valid
      expect(script.errors[:base]).to eq ['executable settings, name, and media type must all be present or all be blank']
    end

    it 'allows an empty settings file' do
      script = build(:script, executable_settings_name: 'settings.txt', executable_settings_media_type: 'text/plain',
        executable_settings: '')

      expect(script).to be_valid

      script.executable_settings = nil

      expect(script).not_to be_valid
      expect(script.errors[:base]).to eq ['executable settings, name, and media type must all be present or all be blank']
    end

    it 'validates that if settings name is nil, then a command that uses a config template placeholder will not be considered valid' do
      script = build(
        :script,
        executable_settings_name: nil,
        executable_settings_media_type: nil,
        executable_settings: nil,
        executable_command: 'echo "{config}" "{source}" "{output_dir}"'
      )
      expect(script).not_to be_valid
      expect(script.errors[:executable_command]).to eq ['contains one of `config_dir`, `config_basename`, `config` but no settings are provided']
    end
  end

  describe 'analysis identifier' do
    [
      ['aa', true],
      ['01', true],
      ['0.0', false],
      ['a.a', false],
      ['A', false],
      ['a1', true],
      ['-a1b', false],
      ['a1b-', false],
      ['a_-__1-b', true],
      ['a_-__1-b_', false],
      ['_a_-__1-b', false], ['-', false],
      ['_', false],
      ['a*a', false]
    ].each do |identifier, expected|
      it "validates the analysis identifier #{identifier} is #{expected ? '' : 'in'}valid" do
        expect(build(:script, analysis_identifier: identifier)).to be_valid if expected
        expect(build(:script, analysis_identifier: identifier)).not_to be_valid unless expected
      end
    end

    it 'validates the uniqueness of the analysis identifier' do
      first = create(:script, analysis_identifier: 'test')
      second = create(:script, analysis_identifier: 'test', group_id: first.group_id)

      # a different group
      third = build(:script, analysis_identifier: 'test')

      fourth = build(:script, analysis_identifier: 'testy-test')

      expect(first.group_id).to eq(second.group_id)
      expect(first).to be_valid
      expect(second).to be_valid

      expect(third.group_id).not_to eq(first.group_id)
      expect(third).not_to be_valid

      expect(fourth).to be_valid
    end
  end

  describe 'arel' do
    let(:provenance) { create(:provenance, name: 'Bird NET', version: '2.1.3') }
    let(:script) {
      create(:script, name: 'BirdNET embeddings', analysis_identifier: 'birdnet-embeddings', version: 1.0,
        provenance:)
    }

    it 'can generate an identifier and version in sql' do
      result = Script.where(id: script.id).pick(Script.analysis_identifier_and_version_arel)

      expect(result).to eq('birdnet-embeddings_2.1.3')
    end

    it 'can generate an identifier and latest version in sql' do
      result = Script.where(id: script.id).pick(Script.analysis_identifier_and_latest_version_arel)

      expect(result).to eq('birdnet-embeddings_latest')
    end

    it 'can generate the name and version in arel' do
      result = Script.where(id: script.id).pick(Script.name_and_version_arel)

      expect(result).to eq('BirdNET embeddings (2.1.3)')
    end

    it 'can generate the name and latest version in arel' do
      result = Script.where(id: script.id).pick(Script.name_and_latest_version_arel)

      expect(result).to eq('BirdNET embeddings (latest)')
    end
  end

  it 'validates version increasing on creation' do
    original = create(:script, version: 1.0)

    new = build(:script, group_id: original.group_id, version: 0.5)

    expect(new).not_to be_valid
  end

  it 'ensures the group_id is the same as the initial id' do
    script = create(:script, version: 1.0)

    expect(script.group_id).to be script.id
  end

  describe 'latest and earliest versions' do
    let!(:three_versions) {
      first = create(:script, version: 1.0, id: 999)
      [
        first,
        create(:script, version: 5, group_id: first.id),
        create(:script, version: 6, group_id: first.id)
      ]
    }

    it 'when there\'s only item in the group, it is both latest and earliest' do
      script = create(:script)
      expect(script.is_last_version?).to be true
      expect(script.is_first_version?).to be true
    end

    it 'shows when a script is the latest version' do
      expect(three_versions[0].is_last_version?).to be false
      expect(three_versions[1].is_last_version?).to be false
      expect(three_versions[2].is_last_version?).to be true
    end

    it 'shows when a script is the earliest version' do
      expect(three_versions[0].is_first_version?).to be true
      expect(three_versions[1].is_first_version?).to be false
      expect(three_versions[2].is_first_version?).to be false
    end
  end

  describe 'executable command' do
    it 'validates the command can be templated (missing source)' do
      script = build(:script)
      script.executable_command = 'exit 1'

      expect(script).not_to be_valid
      expect(script.errors[:executable_command]).to include(
        'Missing required placeholders in command: `source_dir` or `source`'
      )
    end

    it 'validates the command can be templated (output)' do
      script = build(:script)
      script.executable_command = 'echo "{source}"'

      expect(script).not_to be_valid
      expect(script.errors[:executable_command]).to include(
        'Missing required placeholders in command: `output_dir`'
      )
    end

    it 'validates the command can not contain invalid placeholders' do
      script = build(:script)
      script.executable_command = 'echo "{source} {output_dir} {invalid}"'

      expect(script).not_to be_valid
      expect(script.errors[:executable_command]).to include(
        'Invalid placeholder `invalid` in command'
      )
    end

    it 'allows new lines and tabs in the command' do
      script = build(:script)
      script.executable_command = "echo \"hello\nwo\trld\" {source_dir} {output_dir}"

      expect(script).to be_valid
    end

    [
      "\0",
      "\x01",
      "\r\n",
      "\r",
      "\u0099"
    ].each do |bad_character|
      it "rejects bad characters in the command like #{bad_character.dump}" do
        script = build(:script)
        script.executable_command = "echo \"hello#{bad_character}world\""

        expect(script).not_to be_valid
        expect(script.errors[:executable_command]).to include(
          'contains unsafe characters'
        )
      end
    end
  end

  describe 'resources' do
    it 'defaults to a non-nil DynamicResourceList' do
      script = Script.new
      expect(script.resources).to be_a(BawWorkers::BatchAnalysis::DynamicResourceList)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({})
    end

    it 'converts nil to a DynamicResourceList' do
      script = Script.new
      script.resources = nil
      expect(script.resources).to be_a(BawWorkers::BatchAnalysis::DynamicResourceList)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({})
    end

    it 'converts a database nil to a DynamicResourceList' do
      script = create(:script, resources: nil)
      script.reload
      expect(script.resources).to be_a(BawWorkers::BatchAnalysis::DynamicResourceList)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({})
    end

    it 'converts an empty object to a DynamicResourceList' do
      script = create(:script, resources: {})
      script.reload

      expect(script.resources).to be_a(BawWorkers::BatchAnalysis::DynamicResourceList)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({})
    end

    it 'supports partial specification of resources' do
      script = Script.new
      script.resources = script.resources.new(ncpus: 12)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({ ncpus: 12 })
    end

    it 'supports full specification of resources' do
      script = Script.new
      script.resources = script.resources.new(ncpus: 12, mem: 1024, walltime: 3600, ngpus: 1)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({ ncpus: 12, mem: 1024, walltime: 3600, ngpus: 1 })
    end

    it 'supports scaling of resources' do
      script = Script.new
      script.resources = script.resources.new(
        ncpus: { coefficients: [3], property: :duration },
        mem: { coefficients: [2, 1024], property: :size },
        walltime: { coefficients: [4, 2, 3600], property: :duration },
        ngpus: 1
      )

      result = script.resources.calculate(recording_duration: 123, recording_size: 456)
      expect(result).to eq({
        ncpus: 3,
        mem: 1024 + (2 * 456),
        walltime: 3600 + (2 * 123) + (4 * 123 * 123),
        ngpus: 1
      })
    end

    it 'supports minimum values for resources' do
      script = Script.new
      script.resources = script.resources.new(ncpus: 0, mem: 0, walltime: 0, ngpus: 0)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456, minimums: {
        ncpus: 1,
        mem: 1024,
        walltime: 3600,
        ngpus: 1
      })

      expect(result).to eq({
        ncpus: 1,
        mem: 1024,
        walltime: 3600,
        ngpus: 1
      })
    end

    it 'does not inject unintended minimum values for resources' do
      script = Script.new
      script.resources = script.resources.new(ncpus: nil, mem: nil, walltime: nil)

      result = script.resources.calculate(recording_duration: 123, recording_size: 456, minimums: {
        ncpus: 1,
        mem: 1024,
        walltime: 3600
      })

      expect(result).to eq({
        ncpus: 1,
        mem: 1024,
        walltime: 3600
      })
    end

    it 'supports minimums and dynamic scaling of resources' do
      script = Script.new
      script.resources = script.resources.new(
        ncpus: { coefficients: [3], property: :duration },
        mem: { coefficients: [2, 1024], property: :size },
        walltime: { coefficients: [4, 2, 3600], property: :duration }
      )

      result = script.resources.calculate(recording_duration: 123, recording_size: 456, minimums: {
        ncpus: 8
      })
      expect(result).to eq({
        ncpus: 8,
        mem: 1024 + (2 * 456),
        walltime: 3600 + (2 * 123) + (4 * 123 * 123)
      })
    end

    describe 'combining' do
      def self.make(*coefficients)
        BawWorkers::BatchAnalysis::Polynomial.new(coefficients: coefficients || [], property: :duration)
      end
      [
        [nil, nil, nil],
        [1, nil, 1],
        [nil, 1, 1],
        [1, 2, 3],
        [nil,  make(3, 2, 1), make(3, 2, 1)],
        [make(3, 2, 1), nil, make(3, 2, 1)],
        [make(3, 2, 1), 2, make(3, 2, 3)],
        [6, make(3, 2, 1), make(3, 2, 7)],
        [make(3, 2, 1), make(4, 5, 6), make(7, 7, 7)],
        [make(3), make(4, 5, 6), make(4, 5, 9)],
        [make(3, 2, 1), make(4), make(3, 2, 5)],
        [make, make(4, 5, 6), make(4, 5, 6)],
        [make(3, 2, 1), make, make(3, 2, 1)],
        [make, make, make],
        [make, 9, make(9)],
        [9, make, make(9)]

      ].each do |a, b, expected|
        it "we can combine resource lists (a=#{a}, b=#{b})" do
          a = BawWorkers::BatchAnalysis::DynamicResourceList.new(ncpus: a)
          b = BawWorkers::BatchAnalysis::DynamicResourceList.new(ncpus: b)
          actual = a.combine(b)

          expect(actual.ncpus).to eq(expected)
        end
      end
    end
  end
end
