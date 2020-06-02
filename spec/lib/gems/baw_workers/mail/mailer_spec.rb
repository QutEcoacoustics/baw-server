# frozen_string_literal: true

require 'workers_helper'
require 'socket'
require 'rack/utils'

describe BawWorkers::Mail::Mailer do
  context 'test email' do
    let(:to) { 'test1@example.com' }
    let(:from) { 'test2@example.com' }
    let(:job) { { job_class: :job_class_message, job_args: :job_args_message, job_queue: :job_queue_message } }

    let(:error) {

      error = nil
      begin
        0 / 0
      rescue StandardError => e
        error = e
      end

      error
    }

    let(:mail) { BawWorkers::Mail::Mailer.error_notification(to, from, job, error) }

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
      expect(mail.body.encoded).to include(job[:job_class].to_s)
      expect(mail.body.encoded).to include(job[:job_args].to_s)
      expect(mail.body.encoded).to include(job[:job_queue].to_s)
      expect(mail.body.encoded).to include(error.message)
      expect(mail.body.encoded).to include(error.backtrace[0])

      expect(mail.body.encoded).to include(Rack::Utils.escape_html(job[:job_class].to_s))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(job[:job_args].to_s))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(job[:job_queue].to_s))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(error.message))
      expect(mail.body.encoded).to include(Rack::Utils.escape_html(error.backtrace[0][0..10]))

      expect(mail.body.encoded).to include('<p>')
    end

    it 'sends an email' do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

  end
end
