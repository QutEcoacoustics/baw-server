# frozen_string_literal: true

# either route should have identical permissions
[
  ['/analysis_jobs/{analysis_jobs_id}/results/{audio_recording_id}/{script_id}', :results],
  [
    '/analysis_jobs/{analysis_jobs_id}/artifacts/{project_id}/{region_id}/{site_id}/{recorded_year}/{recorded_month}/{audio_recording_id}/{script_id}',
    :artifacts
  ]
].each do |route, action|
  describe 'Analysis Job Results' do
    create_entire_hierarchy

    before do
      create_analysis_result_file(analysis_jobs_item, Pathname('Test1/Test2/test-CASE.csv'), content: 'hello')
    end

    items_others = Set[:create, :destroy, :new, :update, :filter]

    fails_with = [:not_found, :forbidden]

    describe "permissions for #{action}" do
      # override the default :index and :show actions to change the assertions
      # directory listing (this is equivalent to :index)
      with_custom_action(:index, path: '', verb: :get, expect: -> { expect_data_is_hash })
      # file blob (this is equivalent to :show)
      with_custom_action(:show, path: '/Test1/Test2/test-CASE.csv', verb: :get, expect: lambda {
        expect_binary_response('text/csv')
      })

      items_reading = Set[:index, :show]

      given_the_route route do
        {
          analysis_jobs_id: analysis_job.id,
          project_id: project.id,
          region_id: region.id,
          site_id: site.id,
          recorded_year: audio_recording.recorded_date.strftime('%Y'),
          recorded_month: audio_recording.recorded_date.strftime('%Y-%m'),
          audio_recording_id: analysis_jobs_item.audio_recording.id,
          script_id: analysis_jobs_item.script.id
          # id not needed because we're not using the standard :show test
        }
      end

      using_the_factory :analysis_jobs_item

      for_lists_expects do |user, _action|
        case user
        when :admin, :harvester
          AnalysisJobsItem.all
        when :owner, :reader, :writer
          analysis_jobs_item
        else
          []
        end
      end

      # not used
      send_update_body do
        [{}, :json]
      end

      # not used
      send_create_body do
        [{}, :json]
      end

      ensures(:admin, can: items_reading, cannot: items_others, fails_with:)
      ensures(:harvester, cannot: items_others + items_reading, fails_with:)

      # Analysis jobs items are tied to the audio recordings a user has access to
      ensures(:writer, :owner, :reader, can: items_reading, cannot: items_others, fails_with:)

      # No access doesn't have access to any audio
      ensures(:no_access, cannot: items_reading + items_others, fails_with:)
      ensures(:anonymous, cannot: items_reading + items_others, fails_with: [:unauthorized, :not_found])

      ensures :invalid, cannot: items_reading + items_others, fails_with: [:unauthorized, :not_found]
    end
  end
end
