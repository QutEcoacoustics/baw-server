# frozen_string_literal: true

require 'socket'
require 'rack/utils'

describe BawWorkers::Mail::Mailer, type: :mailer do
  # Keep enqueued jobs in the queue so we can assert on them and run them
  # in-process, instead of having the live worker race to dequeue them.
  pause_all_jobs

  let(:queue) { Settings.actions.mailer.queue }

  let(:error) {
    begin
      0 / 0
    rescue StandardError => e
      e
    end
  }

  before do
    clear_pending_jobs
    ActionMailer::Base.deliveries.clear
  end

  describe '.send_worker_error_email' do
    # This exercises the full async path: it enqueues a real
    # `ActionMailer::MailDeliveryJob` and then performs it. Because the job
    # arguments must be serialized by ActiveJob, this catches non-serializable
    # arguments (such as a raw exception or class), which the previous tests
    # missed by either stubbing `error_notification` or using `deliver_now`.
    it 'enqueues a serializable job and delivers it' do
      expect {
        BawWorkers::Mail::Mailer.send_worker_error_email('SomeJobClass', ['argument'], 'queue_name', error)
      }.not_to(change { ActionMailer::Base.deliveries.count })

      expect_and_deliver_async_email

      mail = ActionMailer::Base.deliveries.last
      expect(mail.body.encoded).to include('SomeJobClass')
      expect(mail.body.encoded).to include('queue_name')
      expect(mail.body.encoded).to include(error.message)
    end

    it 'copes with nil job details and a nil error' do
      expect {
        BawWorkers::Mail::Mailer.send_worker_error_email(nil, nil, nil, nil)
      }.not_to(change { ActionMailer::Base.deliveries.count })

      expect_and_deliver_async_email
    end
  end

  context 'test email' do
    let(:to) { 'test1@example.com' }
    let(:from) { 'test2@example.com' }

    let(:details) {
      BawWorkers::Mail::Mailer.build_details(:job_class_message, :job_args_message, :job_queue_message, error)
    }

    let(:mail) { BawWorkers::Mail::Mailer.error_notification(to, from, details) }

    it 'renders the subject' do
      expect(mail.subject).to eql("[#{Socket.gethostname}][prefix] #{error.message}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eql([to])
    end

    it 'renders the sender email' do
      expect(mail.from).to eql([from])
    end

    it 'assigns job and error values' do
      expect(mail.body.encoded).to include(details[:job_class].to_s)
      expect(mail.body.encoded).to include(details[:job_args].to_s)
      expect(mail.body.encoded).to include(details[:job_queue].to_s)
      expect(mail.body.encoded).to include(error.message)
      expect(mail.body.encoded).to include(error.backtrace[0])

      expect(mail.body.encoded).to include(Rack::Utils.escape_html(details[:job_class].to_s))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(details[:job_args].to_s))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(details[:job_queue].to_s))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(error.message))
      expect(mail.body.encoded).to include(error.backtrace[0][0..10])

      expect(mail.body.encoded).to include('<p>')
    end

    it 'sends an email' do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
