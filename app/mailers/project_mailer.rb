class ProjectMailer < ActionMailer::Base
  default from: Settings.devise.mailer_sender

  def project_access_request(sender_user, project_ids, reason)
    @sender_user = sender_user
    @access_reason = reason

    user_projects = {}

    project_ids.each do |project_id|
      unless project_id.blank?
        project = Project.where(id: project_id).first
        receiver_user = project.owner

        unless user_projects.include? receiver_user.user_name
          user_projects[receiver_user.user_name] =
              {
                  email: receiver_user.email,
                  user_name: receiver_user.user_name,
                  projects: []
              }
        end

        user_projects[receiver_user.user_name][:projects] <<
            {
                name: project.name,
                id: project_id
            }
      end
    end

    messages = []

    user_projects.each do |key,value|
      email = value[:email]
      @owner_name = value[:user_name]
      subject = "#{Settings.exception_notification.email_prefix} #{@sender_user.user_name} is requesting access to one or more of your projects."
      @projects = value[:projects]

      messages << mail(to: email, subject: subject)
    end

    messages
  end
end