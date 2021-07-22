# frozen_string_literal: true

module MailerHelpers
  # config.extend allows these methods to be used in describe/context groups
  module ExampleGroup
  end

  # config.include allows these methods to be used in specs/before/let
  module Example
    def clear_mail
      ActionMailer::Base.deliveries.clear
    end

    def expect_no_sent_mail
      aggregate_failures do
        expect(ActionMailer::Base.deliveries.size).to eq(0)
        expect(ActionMailer::Base.deliveries).to eq []
      end
    end
  end
end
