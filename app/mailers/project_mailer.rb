class ProjectMailer < ActionMailer::Base
  default from: Settings.emails.sender_address

  def project_access_request(sender_user, project_ids, reason)
    @sender_user = sender_user
    @access_reason = reason

    user_projects = {}

    project_ids.each do |project_id|
      unless project_id.blank?
        project = Project.where(id: project_id).first
        receiver_user = project.creator

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

    user_projects.each do |key, value|
      # emails get sent to project owner plus required recipients (e.g. admins)
      emails = [value[:email]] + Settings.emails.required_recipients
      @owner_name = value[:user_name]
      subject = "#{Settings.emails.email_prefix} [Project Access Request] #{@sender_user.user_name} is requesting access to one or more projects."
      @projects = value[:projects]
      mail(to: emails, subject: subject).deliver
    end
  end
end