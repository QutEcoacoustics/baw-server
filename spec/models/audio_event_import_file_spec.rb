# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_import_files
#
#  id                                                                                             :bigint           not null, primary key
#  additional_tag_ids(Additional tag ids applied for this import)                                 :integer          is an Array
#  file_hash(Hash of the file contents used for uniqueness checking)                              :text
#  path(Path to the file on disk, relative to the analysis job item. Not used for uploaded files) :string
#  created_at                                                                                     :datetime         not null
#  analysis_jobs_item_id                                                                          :integer
#  audio_event_import_id                                                                          :integer          not null
#
# Indexes
#
#  index_audio_event_import_files_on_analysis_jobs_item_id  (analysis_jobs_item_id)
#  index_audio_event_import_files_on_audio_event_import_id  (audio_event_import_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_jobs_item_id => analysis_jobs_items.id) ON DELETE => cascade
#  fk_rails_...  (audio_event_import_id => audio_event_imports.id) ON DELETE => cascade
#
describe AudioEventImportFile do
  subject { build(:audio_event_import_file, :with_file) }

  it 'has a valid factory (with_file)' do
    expect(create(:audio_event_import_file, :with_file)).to be_valid
  end

  it 'has a valid factory (with_path)' do
    expect(create(:audio_event_import_file, :with_path)).to be_valid
  end

  it { is_expected.to belong_to(:audio_event_import) }
  it { is_expected.to belong_to(:analysis_jobs_item).optional }

  it { is_expected.to have_many(:audio_events) }

  it 'validates that a path or file must be specified' do
    built = build(:audio_event_import_file, path: nil, file: nil)
    expect(built).not_to be_valid
    expect(built.errors[:base]).to include('Either a path or a file must be specified')
  end

  it 'validates that both path and file cannot be specified' do
    built = build(:audio_event_import_file, :with_file, path: 'path/to/file.csv')
    expect(built).not_to be_valid
    expect(built.errors[:base]).to include('Specify either a path or a file, not both')
  end

  it 'validates that a path requires an analysis_jobs_item association' do
    built = build(:audio_event_import_file, path: 'path/to/file.csv')
    expect(built).not_to be_valid
    expect(built.errors[:base]).to include('Path requires an analysis_jobs_item association')
  end

  it 'validates that an analysis_jobs_item association requires a path' do
    built = build(:audio_event_import_file, :with_path, path: nil)
    expect(built).not_to be_valid
    expect(built.errors[:base]).to include('analysis_jobs_item association requires a path')
  end

  it 'validates that the path exists' do
    built = build(:audio_event_import_file, path: 'path/to/nonexistent/file.csv')
    expect(built).not_to be_valid
    expect(built.errors[:path]).to include('does not exist')
  end

  it 'can return the absolute path for an analysis result' do
    built = build(:audio_event_import_file, :with_path)
    expect(built.absolute_path).to be_a(Pathname)
    expect(built.absolute_path).to be_absolute
    expect(built.absolute_path).to be_exist
  end

  it 'returns a nil absolute path if no analysis_jobs_item is associated' do
    built = build(:audio_event_import_file, :with_file)
    expect(built.absolute_path).to be_nil
  end

  it 'raises an exception if additional_tag_ids are not an array of integers' do
    expect {
      subject.additional_tag_ids = [
        nil,
        'not an integer',
        0,
        "'--; DROP TABLE users; --",
        '0asbc',
        true
      ]
    }.to raise_error(ArgumentError, 'additional_tag_ids must be an array of integers')
  end

  it 'can set additional_tag_ids to an array of integers' do
    subject.additional_tag_ids = [1, 2, 3]
    expect(subject.additional_tag_ids).to eq([1, 2, 3])
  end

  it 'can return the additional tags' do
    tag = create(:tag)
    subject.additional_tag_ids = [tag.id]
    expect(subject.additional_tags).to eq([tag])
  end

  it 'validates that the additional tags exist' do
    subject.additional_tag_ids = [9_999_999]
    expect(subject).not_to be_valid
    expect(subject.errors[:additional_tag_ids]).to include('contains invalid tag ids')
  end

  describe 'name_arel' do
    it 'works for a file with a path' do
      model = create(:audio_event_import_file, :with_path)

      AudioEventImportFile
        .where(id: model.id)
        .left_outer_joins(:file_blob)
        .select(AudioEventImportFile.name_arel.as('name'))
        .first => with_field

      expect(with_field[:name]).to eq(File.basename(model.path))
    end

    it 'works for a file with an attached file' do
      model = create(:audio_event_import_file, :with_file)

      AudioEventImportFile
        .where(id: model.id)
        .left_outer_joins(:file_blob)
        .select(AudioEventImportFile.name_arel.as('name'))
        .first => with_field

      expect(with_field[:name]).to eq(model.file.blob.filename.to_s)
    end
  end

  it_behaves_like 'cascade deletes for', :audio_event_import_file, {
    audio_events: {
      taggings: nil,
      comments: nil,
      verifications: nil
    }
  } do
    create_entire_hierarchy
  end
end
