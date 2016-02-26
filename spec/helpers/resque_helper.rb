def emulate_resque_worker_with_job(job_class, job_args, opts={})
  # see http://stackoverflow.com/questions/5141378/how-to-bridge-the-testing-using-resque-with-rspec-examples
  queue = opts[:queue] || 'test_queue'

  Resque::Job.create(queue, job_class, *job_args)

  emulate_resque_worker(queue, opts[:verbose], opts[:fork])
end

def emulate_resque_worker(queue, verbose, fork)
  queue = queue || 'test_queue'

  worker = Resque::Worker.new(queue)
  worker.very_verbose = true if verbose

  if fork
    # do a single job then shutdown
    def worker.done_working
      super
      shutdown
    end

    worker.work(0.5)
  else
    job = worker.reserve
    worker.perform(job)
  end
end