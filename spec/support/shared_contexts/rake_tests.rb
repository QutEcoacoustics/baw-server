# http://robots.thoughtbot.com/test-rake-tasks-like-a-boss
# http://pivotallabs.com/how-i-test-rake-tasks/

shared_context 'rake_tests' do
  # let(:rake_application) {
  #   Rake.application
  # }
  let(:rake_task_name) { self.class.top_level_description }

  def run_rake_task(task_name, args)
    the_task = Rake::Task[task_name]

    #args = [] if args.blank?
    #task_args = Rake::TaskArguments.new(the_task.arg_names, args)
    #the_task.execute(task_args)

    the_task.reenable
    the_task.invoke(*args)
  end

  #let(:rake_task_path)          { File.join('tasks', "#{rake_task_name.split(':').second}") }
  #subject { Rake::Task[rake_task_name] }

  # let :top_level_path do
  #   File.join(File.dirname(__FILE__), '..', '..', '..')
  # end
  #
  # let :run_rake_task do
  #   subject.reenable
  #   Rake.application.invoke_task rake_task_name
  # end

  # def loaded_files_excluding_current_rake_file
  #   $".reject {|file| file == File.join(top_level_path, ("#{task_path}.rake")) }
  # end

  # before do
  #   #Rake.application = rake
  #   #Rake.application.rake_require(rake_task_path, [top_level_path.to_s], loaded_files_excluding_current_rake_file)
  #   Rake.application.rake_require(rake_task_path)
  #
  #   #Rake::Task.define_task(:environment)
  # end
end