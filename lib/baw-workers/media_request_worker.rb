module BawWorkers
  class MediaRequestWorker < PullWorker
    @queue = :media

    def self.perform(options)
      puts "MediaRequestWorker: #{options}"
    end
  end
end