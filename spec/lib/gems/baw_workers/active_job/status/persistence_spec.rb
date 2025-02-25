# frozen_string_literal: true

describe BawWorkers::ActiveJob::Status::Persistence do
  let(:persistence) { BawWorkers::ActiveJob::Status::Persistence }

  let(:basic_status) {
    BawWorkers::ActiveJob::Status::StatusData.new(
      job_id: 'a_job_id',
      name: 'a cat in a hat',
      status: BawWorkers::ActiveJob::Status::STATUS_QUEUED,
      messages: [],
      options: { arguments: ['green eggs and ham'] },
      progress: 0,
      total: 1
    )
  }

  let(:another_status) {
    BawWorkers::ActiveJob::Status::StatusData.new(
      job_id: 'another_job_id',
      name: 'I DO NOT LIKE THEM, SAM-I-AM.',
      status: BawWorkers::ActiveJob::Status::STATUS_WORKING,
      messages: [],
      options: { arguments: ['NOT IN A BOX. NOT WITH A FOX.'] },
      progress: 50,
      total: 1000
    )
  }

  it 'can create a status' do
    expect(persistence.create(basic_status)).to be true
  end

  it 'exists can detect a created a status' do
    expect(persistence.create(basic_status)).to be true

    expect(persistence.exists?('a_job_id')).to be true
  end

  it 'exists will not detect a status that does not exist' do
    expect(persistence.exists?('a_job_id')).to be false
  end

  it 'when a status is created, it is added to a scored set' do
    expect(persistence.create(basic_status)).to be true
    expect(persistence.count).to eq 1
    expect(persistence.create(basic_status)).to be false
    expect(persistence.count).to eq 1
    expect(persistence.create(another_status)).to be true
    expect(persistence.count).to eq 2
  end

  it 'does not overwrite an existing status' do
    expect(persistence.create(basic_status)).to be true
    updated_status = basic_status.new(status: BawWorkers::ActiveJob::Status::STATUS_WORKING)
    expect(persistence.create(updated_status)).to be false
    expect(persistence.get(basic_status.job_id)).to eq(basic_status)
  end

  it 'does not update a status that does not exist' do
    expect(persistence.set(basic_status)).to be false
  end

  it 'can remove a created a status' do
    expect(persistence.create(basic_status)).to be true

    expect(persistence.exists?('a_job_id')).to be true
    expect(persistence.remove('a_job_id')).to be true
    expect(persistence.exists?('a_job_id')).to be false
  end

  context 'when querying' do
    before do
      expect(persistence.create(basic_status)).to be true
      expect(persistence.create(another_status)).to be true
    end

    it 'can get multiple statuses' do
      result = persistence.get_many('a_job_id', 'another_job_id')
      expect(result).to contain_exactly(basic_status, another_status)
    end

    it 'can query status ids' do
      expect(persistence.get_status_ids).to eq(['another_job_id', 'a_job_id'])
    end

    it 'can query status ids by page' do
      expect(persistence.get_status_ids(0, 0)).to eq(['another_job_id'])
      expect(persistence.get_status_ids(1, 10)).to eq(['a_job_id'])
    end

    it 'can query statuses' do
      expect(persistence.get_statuses).to contain_exactly(another_status, basic_status)
    end

    it 'can query statuses by page' do
      expect(persistence.get_statuses(0, 0)).to eq([another_status])
      expect(persistence.get_statuses(1, 10)).to eq([basic_status])
    end
  end

  context 'with old statuses present:' do
    def make_old(num)
      BawWorkers::ActiveJob::Status::StatusData.new(
        job_id: "old_#{num}",
        name: "old #{num}",
        status: BawWorkers::ActiveJob::Status::TERMINAL_STATUSES.rotate(num).first,
        messages: [],
        options: {},
        progress: num,
        total: 1000
      )
    end

    let(:now) { Time.zone.now }

    before do
      Timecop.freeze(now)
      success = persistence.create(make_old(1)).tap { |_| Timecop.travel(10) } &&
                persistence.create(make_old(2)).tap { |_| Timecop.travel(10) } &&
                persistence.create(make_old(3)).tap { |_| Timecop.travel(10) } &&
                persistence.create(make_old(4)).tap { |_| Timecop.travel(10) }
      expect(success).to be true
    end

    after do
      Timecop.return
    end

    it 'tells us there are 4 statuses' do
      # sleep(120)
      assert_count(4)
    end

    it 'can clean old statuses' do
      Timecop.travel(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
      Timecop.travel(60) # for good measure

      persistence.clean_known_statuses
      assert_count(0)
    end

    it 'does not clean statuses that have not expired' do
      persistence.clean_known_statuses
      assert_count(4)
    end

    it 'cleans old statuses when a new status is made, if they have expired' do
      Timecop.travel(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
      Timecop.travel(60) # for good measure

      expect(persistence.create(basic_status)).to be true
      assert_count(1)
    end

    it 'does not clean old statuses when a new status is made, if they have not expired' do
      expect(persistence.create(basic_status)).to be true
      assert_count(5)
    end

    it 'clears statuses (despite their ttl)' do
      persistence.clear
      assert_count(0)
    end

    it 'clears statuses by index (despite their ttl)' do
      expect(persistence.clear(0, 2)).to eq 3
      assert_count(1)
    end

    it 'clears statuses, filtering on status' do
      expect(persistence.clear(status: BawWorkers::ActiveJob::Status::STATUS_KILLED)).to eq 1
      assert_count(3)
    end

    def assert_count(count)
      aggregate_failures 'assert count' do
        expect(persistence.count).to eq(count)
        expect(persistence.get_status_ids).to have_attributes(length: count)
        expect(persistence.get_statuses).to have_attributes(length: count)
      end
    end
  end

  context 'when killing:' do
    before do
      expect(persistence.create(basic_status)).to be true
      expect(persistence.create(another_status)).to be true
    end

    example 'the kill list is empty if there is nothing to kill' do
      expect(persistence.mark_for_kill_count).to eq 0
    end

    it 'adds a job to the kill list when killed' do
      persistence.mark_for_kill(basic_status.job_id)
      expect(persistence.mark_for_kill_count).to eq 1
      expect(persistence.marked_for_kill_ids).to eq [basic_status.job_id]
      expect(persistence.should_kill?(basic_status.job_id)).to be true
    end

    it 'removes the job_id from the kill list hwn the job is killed' do
      persistence.mark_for_kill(basic_status.job_id)
      persistence.killed(basic_status.job_id)

      expect(persistence.mark_for_kill_count).to eq 0
      expect(persistence.should_kill?(basic_status.job_id)).to be false
    end

    it 'removes to job_id from the kill list when the status is removed' do
      persistence.mark_for_kill(basic_status.job_id)
      expect(persistence.mark_for_kill_count).to eq 1
      persistence.remove(basic_status.job_id)
      expect(persistence.mark_for_kill_count).to eq 0
    end

    it 'can kill all jobs' do
      persistence.mark_all_for_kill
      expect(persistence.mark_for_kill_count).to eq 2
      expect(persistence.marked_for_kill_ids).to contain_exactly(basic_status.job_id, another_status.job_id)
      expect(persistence.should_kill?(basic_status.job_id)).to be true
      expect(persistence.should_kill?(another_status.job_id)).to be true
    end
  end

  it 'serializes and deserializes and object consistently' do
    serialized = persistence.encode(basic_status)
    expect(serialized).to be_instance_of(String)
    deserialized = persistence.decode(serialized)
    expect(basic_status).to match(deserialized)
  end

  example 'expire_in function changes ttl based on status' do
    BawWorkers::ActiveJob::Status::STATUSES.each do |status|
      expected = if BawWorkers::ActiveJob::Status::TERMINAL_STATUSES.include?(status)
                   BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN
                 else
                   BawWorkers::ActiveJob::Status::Persistence::PENDING_EXPIRE_IN
                 end

      actual = persistence.expire_in(basic_status.new(status: status))
      expect(actual).to eq(expected)
    end
  end
end
