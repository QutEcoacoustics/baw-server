# take in the ActiveRecord AudioRecording (with all attributes) and the dataset model that specifies the metadata.
# use the saved_search attributes to create the { :audiorecording_id, :start_offset, :end_offset } list

class DataSetCreator
  def execute(audio_recording, dataset_metadata)

    date_format_string = '%Y-%m-%d'
    time_format_string = '%H:%M:%S'

    recordings = audio_recording.scoped

    # sites
    unless dataset_metadata.site_ids.blank?
      recordings = recordings.where(site_id: dataset_metadata.site_ids)
    end

    # start time only
    if dataset_metadata.start_date.blank? && !dataset_metadata.start_time.blank?
      start_time_string = dataset_metadata.start_time.strftime(time_format_string)
      recordings = recordings.end_after(start_time_string)
    end

    # start date only
    if !dataset_metadata.start_date.blank? && dataset_metadata.start_time.blank?
      start_date_string = dataset_metadata.start_date.to_time.strftime(date_format_string)
      recordings = recordings.end_after start_date_string
    end

    # both start date and start time
    if !dataset_metadata.start_date.blank? && !dataset_metadata.start_time.blank?
      start_date_time_string = dataset_metadata.start_date.to_time.strftime(date_format_string)+'T'+dataset_metadata.start_time.strftime(time_format_string)
      recordings = recordings.end_after start_date_time_string
    end

    # end time only
    if dataset_metadata.end_date.blank? && !dataset_metadata.end_time.blank?
      end_time_string = dataset_metadata.end_time.strftime(time_format_string)
      recordings = recordings.start_before end_time_string
    end

    # end date only
    if !dataset_metadata.end_date.blank? && dataset_metadata.end_time.blank?
      end_date_string = dataset_metadata.end_date.to_time.strftime(date_format_string)
      recordings = recordings.start_before end_date_string
    end

    # both end date and end time
    if !dataset_metadata.end_date.blank? && !dataset_metadata.end_time.blank?
      end_date_time_string = dataset_metadata.end_date.to_time.strftime(date_format_string)+'T'+dataset_metadata.end_time.strftime(time_format_string)
      recordings = recordings.start_before end_date_time_string
    end

    unless dataset_metadata.number_of_tags.blank?
      #recordings = recordings.where(tags: )
    end

    # date format: YYYY-MM-DD
    # time format: HH:mm:SS.SSS
    # date and time format: YYYY-MM-DDTHH:mm:SS.SSS


    #if dataset_metadata.start_date
    #  audio_recording = audio_recording.start_before(dataset_metadata.start_date)
    #end
    #
    #if dataset_metadata.start_time
    #  audio_recording = audio_recording.start_before(dataset_metadata.start_date)
    #end
    #
    #if dataset_metadata.end_date
    #
    #end
    #
    #if dataset_metadata.end_time
    #
    #end
    #
    #audio_recording.e

    #dataset_metadata.start_date.iso8601
    #dataset_metadata.end_date.iso8601

    recordings.explain
    recordings
  end
end