# frozen_string_literal: true

describe TempFileHelpers do
  it 'defines a temp path helper' do
    expect(temp_dir).to be_an_instance_of(Pathname).and be_exist
  end

  context 'creating an deleting files' do
    it 'can create and clean a temp file' do |example|
      stem = 'abc'
      temp_path = temp_dir / "#{stem}.tmp"

      temp_path.unlink if temp_path.exist?

      expect(File.exist?(temp_path)).to be false

      subject = RSpec.describe('sub-group in temp file spec') {
        include TempFileHelpers::Example

        before do
          expect(File.exist?(temp_path)).to be false
        end

        it 'temp file user' do
          p = temp_file(stem:)

          FileUtils.touch(p)

          expect(p.exist?).to be true
        end
      }

      subject.run(example.reporter)

      expect(File.exist?(temp_dir / "#{stem}.tmp")).to be false
    end

    it 'can cleans temp files between examples' do |example|
      stem = 'abc'
      temp_path = temp_dir / "#{stem}.tmp"

      temp_path.unlink if temp_path.exist?

      expect(File.exist?(temp_path)).to be false

      subject = RSpec.describe('sub-group in temp file spec') {
        include TempFileHelpers::Example

        before do
          expect(File.exist?(temp_path)).to be false
        end

        it 'temp file user' do
          p = temp_file(stem:)

          FileUtils.touch(p)

          expect(p.exist?).to be true
        end

        it 'temp file user2' do
          p = temp_file(stem:)

          FileUtils.touch(p)

          expect(p.exist?).to be true
        end
      }

      subject.run(example.reporter)

      expect(File.exist?(temp_dir / "#{stem}.tmp")).to be false
    end
  end
end
