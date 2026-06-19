# frozen_string_literal: true

# Verifies that emails which used to be delivered synchronously are now
# delivered asynchronously via ActiveJob (Resque). See https://github.com/QutEcoacoustics/baw-server/issues/1004.
#
# Jobs are performed in-process with `perform_job_locally` so that the rendered
# email lands in this process's `ActionMailer::Base.deliveries` and shares the
# test's database connection.
describe 'asynchronous email delivery', type: :mailer do
  # Pause the resque worker so enqueued jobs stay in the queue for assertions
  # instead of being raced away by the live worker process. Jobs are then run
  # in-process with `perform_job_locally`.
  pause_all_jobs

  let(:queue) { Settings.actions.mailer.queue }

  before do
    clear_pending_jobs
    ActionMailer::Base.deliveries.clear
  end

  describe PublicMailer do
    let(:request_info) { { remote_ip: '203.0.113.7', user_agent: 'rspec-agent' } }

    it 'delivers contact us emails asynchronously' do
      model = DataClass::ContactUs.new(name: 'Jane', email: 'jane@example.com', content: 'hello world')

      expect {
        PublicMailer.contact_us_message(nil, model, request_info).deliver_later
      }.not_to(change { ActionMailer::Base.deliveries.count })

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      perform_job_locally(queue)

      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to include('[Contact Us]').and include('Jane')
      expect(email.body.encoded).to include('hello world')
    end

    it 'delivers data request emails asynchronously (with enumerized attributes)' do
      model = DataClass::DataRequest.new(
        name: 'Jane', email: 'jane@example.com', group: 'Acme', group_type: 'non_profit', content: 'please'
      )

      PublicMailer.data_request_message(nil, model, request_info).deliver_later

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      perform_job_locally(queue)

      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to include('[Data Request]')
      expect(email.body.encoded).to include('non_profit').and include('Acme').and include('please')
    end

    it 'delivers the new user notification asynchronously' do
      user = create(:user)
      ActionMailer::Base.deliveries.clear
      info = DataClass::NewUserInfo.new(name: 'Bob', email: 'bob@example.com')

      PublicMailer.new_user_message(user, info).deliver_later

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      perform_job_locally(queue)

      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to include('[New User Notification]')
      expect(email.body.encoded).to include('Bob')
    end
  end

  describe 'Devise notifications' do
    # Uses deletion cleaning so the `after_commit` callback that defers the
    # confirmation email actually fires (it does not under transactional tests).
    it 'enqueues the confirmation email when a user is created rather than sending it synchronously',
      :clean_by_truncation do
      expect {
        User.create!(
          user_name: 'async confirm',
          email: 'async-confirm@example.com',
          password: 'password123',
          roles_mask: 2,
          skip_creation_email: true
        )
      }.not_to(change { ActionMailer::Base.deliveries.count })

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      perform_job_locally(queue)

      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include('async-confirm@example.com')
      expect(email.body.encoded).to match(/confirm/i)
    end

    it 'delivers reset password instructions asynchronously' do
      user = create(:user)
      ActionMailer::Base.deliveries.clear

      expect {
        user.send_reset_password_instructions
      }.not_to(change { ActionMailer::Base.deliveries.count })

      expect_enqueued_jobs(1, of_class: ActionMailer::MailDeliveryJob)
      perform_job_locally(queue)

      expect(ActionMailer::Base.deliveries.last.to).to include(user.email)
    end
  end
end
