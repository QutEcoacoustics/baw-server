namespace :baw do
  namespace :action do
    namespace :media do

      # No rake tasks - media cutting and spectrogram generation is done on demand for now.
      # If eager generation is needed, rake tasks can be made to enqueue jobs or run standalone
      # Consider defaults and offsets: from start of file, or from time of day e.g. 22:54:00 / 22:54:30 for 30 second segments?

    end
  end
end