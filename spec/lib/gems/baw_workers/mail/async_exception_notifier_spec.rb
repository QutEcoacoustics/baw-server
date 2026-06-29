# frozen_string_literal: true

describe BawWorkers::Mail::AsyncExceptionNotifier, type: :mailer do
  # Keep enqueued jobs in the queue so we can assert on them and run them
  # in-process, instead of having the live worker race to dequeue them.
  pause_all_jobs

  let(:queue) { Settings.actions.mailer.queue }

  let(:error) {
    begin
      raise 'something went terribly wrong'
    rescue StandardError => e
      e
    end
  }

  before do
    clear_pending_jobs
    ActionMailer::Base.deliveries.clear
  end

  it 'is the registered :email exception notifier' do
    expect(ExceptionNotifier.registered_exception_notifier(:email)).to be_a(BawWorkers::Mail::AsyncExceptionNotifier)
  end

  describe 'delivering an exception notification' do
    it 'builds the email synchronously but delivers it asynchronously' do
      # building/enqueuing must not deliver immediately
      expect {
        ExceptionNotifier.notify_exception(error)
      }.not_to(change { ActionMailer::Base.deliveries.count })

      # a raw-email delivery job is enqueued on the mailer queue
      # performing the job actually delivers the email
      expect_and_deliver_async_email(of_class: BawWorkers::Jobs::Mail::DeliverRawEmailJob)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to include('[Exception]')
      expect(mail.to).to match_array(Settings.mailer.emails.required_recipients)
      expect(mail.from).to contain_exactly(Settings.mailer.emails.sender_address)
      expect(mail.body.encoded).to include(error.message)
    end
  end
end
