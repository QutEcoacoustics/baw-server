module CitizenScienceCreation

  # creates 12 dataset items. Every 3rd dataset item has a progress event created by the writer user
  # and every 2nd has a progress event created by the reader user.
  # Half the items are with one audio_recording and the other half with another (alternating between them)
  # Resulting in dataset items 2,4,6,8,10,12 viewed by reader and
  # 3,6,9,12 viewed by writer, and 6,12 viewed by both and 1,5,7,11 not viewed
  # Adding these to the 1 dataset item already created in the create_entire_hierarchy, which
  # has a progress event, there are 13 dataset items, 4 of which are not viewed
  def create_many_dataset_items

    let(:many_dataset_items_some_with_events) {

      # start with the 2 dataset items created in the entire hierarchy
      results = [
          {dataset_item: dataset_item, progress_events: [progress_event_for_no_access_user]},
          {dataset_item: default_dataset_item, progress_events: [progress_event]}
      ]

      # create a progress event for the writer user on every 3rd dataset item
      # and a progress event for the reader user on every 2nd dataset item.
      # some dataset items will have no progress events, some by writer only, some by
      # reader only and some by both
      progress_event_creators = [
          {creator: writer_user, view_every: 3},
          {creator: reader_user, view_every: 2},
      ]

      # make more than 25 to test paging
      num_dataset_items = 32

      # create another audio recording so we can make sure the order is not affected by the audio recording id
      another_audio_recording = FactoryGirl.create(
          :audio_recording,
          :status_ready,
          creator: writer_user,
          uploader: writer_user,
          site: site,
          sample_rate_hertz: 22050)

      audio_recordings = [audio_recording, another_audio_recording]

      # random number generator with seed
      my_rand = Random.new(99)

      # create the dataset items one at a time
      for d in 1..num_dataset_items do

        # create a dataset item with alternating audio recording id
        # So that we can test the audio recording does not affect the order
        dataset_item = FactoryGirl.create(:dataset_item,
                                          creator: admin_user,
                                          dataset: dataset,
                                          audio_recording: audio_recordings[d % 2],
                                          start_time_seconds: d,
                                          end_time_seconds: d+10,
                                          order: my_rand.rand * 10)
        dataset_item.save!

        current_data = {dataset_item: dataset_item, progress_events: [], progress_event_count: 0 }

        # for this dataset item, add a progress even for zero or more of the users
        # If this dataset item is the nth created, add progress events for those users
        # who's view_every value is a factor of n.
        for c in progress_event_creators do
          progress_event = nil
          if d % c[:view_every] == 0
            progress_event = FactoryGirl.create(
                :progress_event,
                creator: c[:creator],
                dataset_item: dataset_item,
                activity: "viewed",
                created_at: "2017-01-01 12:34:56")

            current_data[:progress_events].push(progress_event)
          end
        end

        results.push(current_data)
      end

      results

    }

  end

  # creates and saves many studies, questions and responses
  # allowing proper testing of filter and index
  # Ensures that there are a range of relationships between records
  # So that filtering by (e.g.) questions of a particular study can be properly tested
  def create_many_studies

    let(:many_studies) {

      results = {
          studies: [],
          questions: [],
          # question_studies: {},
          # study_questions: {},
          responses: []
      }


      # only admins can create studies and questions

      response_creators = [
          {creator: writer_user},
          {creator: reader_user}
      ]

      num_studies = 5
      num_questions = 6
      num_responses = 32


      # #random number generator with seed
      # my_rand = Random.new(99)

      for s in 1..num_studies do

        study = FactoryGirl.create(:study,
                                   creator: admin_user,
                                   dataset: dataset,
                                   name: "Test Study #{s}")
        study.save!
        # initialize for later when questions are created
        # results[:study_questions][study.id] = []
        results[:studies].push(study)

      end

      for q in 1..num_questions do

        # number of studies to associate question to is q mod max number
        # pick these at random
        number_related_studies = (q % num_studies) + 1
        study_ids = results[:studies].map(&:id).sample(number_related_studies, random:Random.new(q))

        # study_ids = [results[:studies][0].id,
        #              results[:studies][2].id,
        #              results[:studies][3].id]

        question = FactoryGirl.create(:question,
                                      creator: admin_user,
                                      study_ids: study_ids,
                                      text: "test question text #{q}",
                                      data: {})

        question.save!

        # # the returned Question object does not have the study_ids
        # # so keep track of the relationships here
        # results[:question_studies][question.id] = study_ids
        # study_ids.each do |study_id|
        #   # append the question id to the array of ids for
        #   results[:study_questions][study_id].push(question.id)
        # end


        results[:questions].push(question)


      end

      results

    }


  end


end
