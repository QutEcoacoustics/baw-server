FactoryGirl.define do

  factory :analysis_jobs_item do
    analysis_job
    audio_recording

    queue_id  { SecureRandom.uuid }
    status "new"


  end
end