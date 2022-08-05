# frozen_string_literal: true

describe BawWorkers::Jobs::IntroduceDelay do
  pause_all_jobs

  it 'checks we have patched ApplicationJob' do
    expect(::BawWorkers::Jobs::ApplicationJob.ancestors).to include(BawWorkers::Jobs::IntroduceDelayPatch)
  end

  context 'with a paused jobs' do
    it 'basically works' do
      client_yield = nil
      waiter = introduce_delay(job_class: Fixtures::CheckPointJob, method: :some_work, delay: 1) {
        expect(BawWorkers::Jobs::IntroduceDelay.waiting?).to be true
        client_yield = Time.now
      }
      job = Fixtures::CheckPointJob.perform_later!

      expect(BawWorkers::Jobs::IntroduceDelay.waiting?).to be false
      start = Time.now

      perform_jobs_immediately(count: 1)
      waiter.call
      wait_for_jobs

      stop = Time.now
      expect(BawWorkers::Jobs::IntroduceDelay.waiting?).to be false
      expect(BawWorkers::Jobs::IntroduceDelay.find_hook).to be_nil

      expect_jobs_to_be(completed: 1, of_class: Fixtures::CheckPointJob)

      job.refresh_status!

      before, inside, after = extract_messages(job.status)

      expect_timings(start, before, client_yield, inside, after, stop)
    end
  end

  context 'with free running jobs' do
    perform_all_jobs_normally

    it 'basically works' do
      client_yield = nil
      waiter = introduce_delay(job_class: Fixtures::CheckPointJob, method: :some_work, delay: 1) {
        expect(BawWorkers::Jobs::IntroduceDelay.waiting?).to be true
        client_yield = Time.now
      }

      expect(BawWorkers::Jobs::IntroduceDelay.waiting?).to be false
      start = Time.now

      job = Fixtures::CheckPointJob.perform_later!

      waiter.call
      wait_for_jobs

      stop = Time.now
      expect(BawWorkers::Jobs::IntroduceDelay.waiting?).to be false
      expect_jobs_to_be(completed: 1, of_class: Fixtures::CheckPointJob)

      job.refresh_status!

      before, inside, after = extract_messages(job.status)

      expect_timings(start, before, client_yield, inside, after, stop)
    end
  end

  def expect_timings(start, before, client_yield, inside, after, stop)
    # first assert all block happened in the order expect
    expected = [start, before, client_yield, inside, after, stop]
    actual = expected.sort

    # after sorting order should remain unchanged if array already sorted
    actual.should eq expected

    # and we should see about a second of delay
    # the block is executed when we hit the target method
    expect(client_yield - start).to be_within(0.3).of(0.5)
    expect(client_yield - before).to be_within(0.1).of(0.1)
    # then delay happens before the target method
    expect(inside - client_yield).to be_within(0.2).of(1)
    # then things run normally
    expect(after - inside).to be_within(0.05).of(0.05)
    expect(stop - inside).to be_within(0.1).of(0.45)
  end

  # @param status [BawWorkers::ActiveJob::Status::StatusData]
  def extract_messages(status)
    # 3 we sent plus standard completed message
    expect(status.messages.size).to eq 4

    before = status.messages.map { |x| parse_message(x, /Before.*?:(.*)/) }.compact.first
    inside = status.messages.map { |x| parse_message(x, /In.*?:(.*)/) }.compact.first
    after = status.messages.map { |x| parse_message(x, /After.*?:(.*)/) }.compact.first

    [before, inside, after]
  end

  def parse_message(message, regex)
    match = message.match(regex)
    return nil unless match

    Time.parse(match.captures[0])
  end
end
