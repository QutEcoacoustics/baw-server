# frozen_string_literal: true

describe Filter::Query do
  create_entire_hierarchy

  include SqlHelpers::Example

  def check_filter_sql(filter, expected_sql_fragment)
    filter_query = Filter::Query.new(
      filter,
      AudioRecording.all,
      AudioRecording,
      AudioRecording.filter_settings
    )
    contains_sql(filter_query.query_full.to_sql, expected_sql_fragment)
    filter_query
  end

  context 'case-insensitive operators' do
    describe 'ieq' do
      it 'generates ILIKE SQL for string values' do
        check_filter_sql(
          { filter: { original_file_name: { ieq: 'hello.wav' } } },
          '"audio_recordings"."original_file_name" ILIKE \'hello.wav\''
        )
      end

      it 'generates IS NULL for nil values' do
        check_filter_sql(
          { filter: { original_file_name: { ieq: nil } } },
          '"audio_recordings"."original_file_name" IS NULL'
        )
      end

      it 'escapes LIKE wildcards in the value' do
        check_filter_sql(
          { filter: { original_file_name: { ieq: 'hello%world' } } },
          '"audio_recordings"."original_file_name" ILIKE \'hello\\%world\''
        )
      end

      it 'escapes LIKE underscore wildcards in the value' do
        check_filter_sql(
          { filter: { original_file_name: { ieq: 'hello_world' } } },
          '"audio_recordings"."original_file_name" ILIKE \'hello\\_world\''
        )
      end

      it 'raises an error for non-string, non-nil values' do
        expect {
          Filter::Query.new(
            { filter: { original_file_name: { ieq: 42 } } },
            AudioRecording.all,
            AudioRecording,
            AudioRecording.filter_settings
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError, /Value must be a string/)
      end

      it 'matches records case-insensitively' do
        name = audio_recording.original_file_name
        expect(name).to be_present

        results = Filter::Query.new(
          { filter: { original_file_name: { ieq: name.upcase } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full

        expect(results.pluck(:id)).to include(audio_recording.id)
      end
    end

    describe 'not_ieq' do
      it 'generates NOT ILIKE SQL for string values' do
        check_filter_sql(
          { filter: { original_file_name: { not_ieq: 'hello.wav' } } },
          '"audio_recordings"."original_file_name" NOT ILIKE \'hello.wav\''
        )
      end

      it 'generates IS NOT NULL for nil values' do
        check_filter_sql(
          { filter: { original_file_name: { not_ieq: nil } } },
          '"audio_recordings"."original_file_name" IS NOT NULL'
        )
      end

      it 'escapes LIKE wildcards in the value' do
        check_filter_sql(
          { filter: { original_file_name: { not_ieq: 'hello_world' } } },
          '"audio_recordings"."original_file_name" NOT ILIKE \'hello\\_world\''
        )
      end

      it 'raises an error for non-string, non-nil values' do
        expect {
          Filter::Query.new(
            { filter: { original_file_name: { not_ieq: 123 } } },
            AudioRecording.all,
            AudioRecording,
            AudioRecording.filter_settings
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError, /Value must be a string/)
      end

      it 'excludes exact-case records but still matches different-case records' do
        name = audio_recording.original_file_name
        expect(name).to be_present

        # not_ieq with the exact name: this recording should NOT be in the results
        results = Filter::Query.new(
          { filter: { original_file_name: { not_ieq: name } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full

        expect(results.pluck(:id)).not_to include(audio_recording.id)
      end
    end

    describe 'iin' do
      it 'generates ILIKE OR SQL for an array of string values' do
        sql = Filter::Query.new(
          { filter: { original_file_name: { iin: ['hello.wav', 'world.wav'] } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full.to_sql

        expect(sql).to include('"audio_recordings"."original_file_name" ILIKE \'hello.wav\'')
        expect(sql).to include('"audio_recordings"."original_file_name" ILIKE \'world.wav\'')
        expect(sql).to include(' OR ')
      end

      it 'escapes LIKE wildcards in the values' do
        sql = Filter::Query.new(
          { filter: { original_file_name: { iin: ['hello%wav', 'world_wav'] } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full.to_sql

        expect(sql).to include('"audio_recordings"."original_file_name" ILIKE \'hello\\%wav\'')
        expect(sql).to include('"audio_recordings"."original_file_name" ILIKE \'world\\_wav\'')
      end

      it 'matches records case-insensitively' do
        name = audio_recording.original_file_name
        expect(name).to be_present

        results = Filter::Query.new(
          { filter: { original_file_name: { iin: [name.upcase] } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full

        expect(results.pluck(:id)).to include(audio_recording.id)
      end
    end

    describe 'not_iin' do
      it 'generates NOT (ILIKE OR ILIKE) SQL for an array of string values' do
        sql = Filter::Query.new(
          { filter: { original_file_name: { not_iin: ['hello.wav', 'world.wav'] } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full.to_sql

        expect(sql).to include('NOT')
        expect(sql).to include('"audio_recordings"."original_file_name" ILIKE \'hello.wav\'')
        expect(sql).to include('"audio_recordings"."original_file_name" ILIKE \'world.wav\'')
        expect(sql).to include(' OR ')
      end

      it 'excludes records that match case-insensitively' do
        name = audio_recording.original_file_name
        expect(name).to be_present

        results = Filter::Query.new(
          { filter: { original_file_name: { not_iin: [name.upcase] } } },
          AudioRecording.all,
          AudioRecording,
          AudioRecording.filter_settings
        ).query_full

        expect(results.pluck(:id)).not_to include(audio_recording.id)
      end
    end

    describe 'unrecognised operators still error' do
      it 'raises an error for ieq_not (a made-up operator)' do
        expect {
          Filter::Query.new(
            { filter: { original_file_name: { ieq_not: 'hello.wav' } } },
            AudioRecording.all,
            AudioRecording,
            AudioRecording.filter_settings
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError)
      end
    end
  end
end
