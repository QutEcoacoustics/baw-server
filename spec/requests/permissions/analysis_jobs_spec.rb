require 'rails_helper'

describe 'Analysis Job permissions' do
  create_entire_hierarchy

  before do
    # can only delete an analysis job if it is suspended or completed
    analysis_job.update_column(:overall_status, :completed)
  end

  given_the_route '/analysis_jobs' do
    {
      id: analysis_job.id
    }
  end
  using_the_factory :analysis_job_with_valid_saved_search, model_name: :analysis_job
  for_lists_expects do |user, _action|
    case user
    when :admin
      AnalysisJob.all
    when :owner, :reader, :writer
      analysis_job
    else
      []
    end
  end
  when_updating_send_only :name, :description

  the_user :admin, can_do: everything

  # Analysis jobs are tied to the user that created them.
  # In this case the writer user made the job. They can do most things
  the_users :writer, can_do: everything, and_cannot_do: nothing

  # the reader and owner
  # they can read/create any job as long as they have access to a project included in the job,
  # but can't change ones they don't own
  the_users :reader, :owner, can_do: (reading + creation), and_cannot_do: mutation

  # No access doesn't have access to any audio, so can't create a job and
  # can't read current job
  the_user :no_access, can_do: listing, and_cannot_do: not_listing

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
