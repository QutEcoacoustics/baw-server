# take in the ActiveRecord AudioRecording (with all attributes) and the dataset model that specifies the metadata.
# use the saved_search attributes to create the { :audiorecording_id, :start_offset, :end_offset } list

class DataSetCreator
  def execute(audio_recording, dataset_metadata)

    date_format_string = '%Y-%m-%d'
    time_format_string = '%H:%M:%S'
    date_and_time_format_string = date_format_string+'T'+time_format_string

    recordings = audio_recording.scoped

    # sites
    unless dataset_metadata.site_ids.blank?
      recordings = recordings.where(site_id: dataset_metadata.site_ids)
    end

    # dates - exclude audio outside the start and end dates if they are specified
    unless dataset_metadata.start_date.blank?
      date_string = dataset_metadata.start_date.to_time.strftime(date_format_string)
      recordings = recordings.end_after date_string
    end

    unless dataset_metadata.end_date.blank?
      date_string = dataset_metadata.end_date.to_time.strftime(date_format_string)
      recordings = recordings.start_before date_string
    end

    # times - creates segments

    # number of tags
    unless dataset_metadata.number_of_tags.blank?
      recordings = recordings.tag_count dataset_metadata.number_of_tags
    end

    # types of tags
    #unless dataset_metadata.

    recordings.explain
    recordings
  end
end