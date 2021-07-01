# frozen_string_literal: true

describe BawWorkers::ActiveJob::Status::Persistance do
  let(:persistance) { BawWorkers::ActiveJob::Status::Persistance }

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
    expect(persistance.create(basic_status)).to eq true
  end

  it 'exists can detect a created a status' do
    expect(persistance.create(basic_status)).to eq true

    expect(persistance.exists?('a_job_id')).to eq true
  end

  it 'exists will not detect a status that does not exist' do
    expect(persistance.exists?('a_job_id')).to eq false
  end

  it 'when a status is created, it is added to a scored set' do
    expect(persistance.create(basic_status)).to eq true
    expect(persistance.count).to eq 1
    expect(persistance.create(basic_status)).to eq false
    expect(persistance.count).to eq 1
    expect(persistance.create(another_status)).to eq true
    expect(persistance.count).to eq 2
  end

  it 'will not overwrite an existing status' do
    expect(persistance.create(basic_status)).to eq true
    updated_status = basic_status.new(status: BawWorkers::ActiveJob::Status::STATUS_WORKING)
    expect(persistance.create(updated_status)).to eq false
    expect(persistance.get(basic_status.job_id)).to eq(basic_status)
  end

  it 'will not update a status that does not exist' do
    expect(persistance.set(basic_status)).to eq false
  end

  it 'can remove a created a status' do
    expect(persistance.create(basic_status)).to eq true

    expect(persistance.exists?('a_job_id')).to eq true
    expect(persistance.remove('a_job_id')).to eq true
    expect(persistance.exists?('a_job_id')).to eq false
  end

  context 'when querying' do
    before do
      expect(persistance.create(basic_status)).to eq true
      expect(persistance.create(another_status)).to eq true
    end

    it 'can get multiple statuses' do
      result = persistance.get_many('a_job_id', 'another_job_id')
      expect(result).to contain_exactly(basic_status, another_status)
    end

    it 'can query status ids' do
      expect(persistance.get_status_ids).to eq(['another_job_id', 'a_job_id'])
    end

    it 'can query status ids by page' do
      expect(persistance.get_status_ids(0, 0)).to eq(['another_job_id'])
      expect(persistance.get_status_ids(1, 10)).to eq(['a_job_id'])
    end

    it 'can query statuses' do
      expect(persistance.get_statuses).to contain_exactly(another_status, basic_status)
    end

    it 'can query statuses by page' do
      expect(persistance.get_statuses(0, 0)).to eq([another_status])
      expect(persistance.get_statuses(1, 10)).to eq([basic_status])
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

    let(:now) { Time.now }

    before do
      Timecop.freeze(now)
      success = persistance.create(make_old(1)).tap { |_| Timecop.travel(10) } &&
                persistance.create(make_old(2)).tap { |_| Timecop.travel(10) } &&
                persistance.create(make_old(3)).tap { |_| Timecop.travel(10) } &&
                persistance.create(make_old(4)).tap { |_| Timecop.travel(10) }
      expect(success).to eq true
    end

    after do
      Timecop.return
    end

    it 'tells us there are 4 statuses' do
      # sleep(120)
      assert_count(4)
    end

    it 'can clean old statuses' do
      Timecop.travel(BawWorkers::ActiveJob::Status::Persistance::TERMINAL_EXPIRE_IN)
      Timecop.travel(60) # for good measure

      persistance.clean_known_statuses
      assert_count(0)
    end

    it 'will not clean statuses that have not expired' do
      persistance.clean_known_statuses
      assert_count(4)
    end

    it 'will clean old statuses when a new status is made, if they have expired' do
      Timecop.travel(BawWorkers::ActiveJob::Status::Persistance::TERMINAL_EXPIRE_IN)
      Timecop.travel(60) # for good measure

      expect(persistance.create(basic_status)).to eq true
      assert_count(1)
    end

    it 'will not clean old statuses when a new status is made, if they have not expired' do
      expect(persistance.create(basic_status)).to eq true
      assert_count(5)
    end

    it 'will clear statuses (despite their ttl)' do
      persistance.clear
      assert_count(0)
    end

    it 'will clear statuses by index (despite their ttl)' do
      expect(persistance.clear(0, 2)).to eq 3
      assert_count(1)
    end

    it 'will clear statuses, filtering on status' do
      expect(persistance.clear(status: BawWorkers::ActiveJob::Status::STATUS_KILLED)).to eq 1
      assert_count(3)
    end

    def assert_count(count)
      aggregate_failures 'assert count' do
        expect(persistance.count).to eq(count)
        expect(persistance.get_status_ids).to have_attributes(length: count)
        expect(persistance.get_statuses).to have_attributes(length: count)
      end
    end
  end

  context 'when killing:' do
    before do
      expect(persistance.create(basic_status)).to eq true
      expect(persistance.create(another_status)).to eq true
    end

    example 'the kill list is empty if there is nothing to kill' do
      expect(persistance.mark_for_kill_count).to eq 0
    end

    it 'adds a job to the kill list when killed' do
      persistance.mark_for_kill(basic_status.job_id)
      expect(persistance.mark_for_kill_count).to eq 1
      expect(persistance.marked_for_kill_ids).to eq [basic_status.job_id]
      expect(persistance.should_kill?(basic_status.job_id)).to eq true
    end

    it 'removes the job_id from the kill list hwn the job is killed' do
      persistance.mark_for_kill(basic_status.job_id)
      persistance.killed(basic_status.job_id)

      expect(persistance.mark_for_kill_count).to eq 0
      expect(persistance.should_kill?(basic_status.job_id)).to eq false
    end

    it 'removes to job_id from the kill list when the status is removed' do
      persistance.mark_for_kill(basic_status.job_id)
      expect(persistance.mark_for_kill_count).to eq 1
      persistance.remove(basic_status.job_id)
      expect(persistance.mark_for_kill_count).to eq 0
    end

    it 'can kill all jobs' do
      persistance.mark_all_for_kill
      expect(persistance.mark_for_kill_count).to eq 2
      expect(persistance.marked_for_kill_ids).to eq [basic_status.job_id, another_status.job_id]
      expect(persistance.should_kill?(basic_status.job_id)).to eq true
      expect(persistance.should_kill?(another_status.job_id)).to eq true
    end
  end

  it 'serializes and deserializes and object consistently' do
    serialized = persistance.encode(basic_status)
    expect(serialized).to be_instance_of(String)
    deserialized = persistance.decode(serialized)
    expect(basic_status).to match(deserialized)
  end

  example 'expire_in function changes ttl based on status' do
    BawWorkers::ActiveJob::Status::STATUSES.each do |status|
      expected = if BawWorkers::ActiveJob::Status::TERMINAL_STATUSES.include?(status)
                   BawWorkers::ActiveJob::Status::Persistance::TERMINAL_EXPIRE_IN
                 else
                   BawWorkers::ActiveJob::Status::Persistance::PENDING_EXPIRE_IN
                 end

      actual = persistance.expire_in(basic_status.new(status: status))
      expect(actual).to eq(expected)
    end
  end
end
