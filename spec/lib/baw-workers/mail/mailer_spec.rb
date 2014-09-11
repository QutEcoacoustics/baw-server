require 'spec_helper'
require 'socket'

describe BawWorkers::Mail::Mailer do
  context 'test email' do
    let(:to) {'test1@example.com'}
    let(:from) {'test2@example.com'}
    let(:job) { {job_class: :job_class_message, job_args: :job_args_message} }
    let(:error) { {message: :test3, backtrace: :test4} }
    let(:mail) { BawWorkers::Mail::Mailer.error_notification(to, from, job, error) }

    it 'renders the subject' do
      expect(mail.subject).to eql("[#{Socket.gethostname}][Exception] #{error.message}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eql([to])
    end

    it 'renders the sender email' do
      expect(mail.from).to eql([from])
    end

    it 'assigns job and error values' do
      expect(mail.body.encoded).to match(job.job_class.to_s)
      expect(mail.body.encoded).to match(job.job_args.to_s)
      expect(mail.body.encoded).to match(error.message.to_s)
      expect(mail.body.encoded).to match(error.backtrace.to_s)
    end

    it "sends an email" do
      expect { mail.deliver }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

  end
end