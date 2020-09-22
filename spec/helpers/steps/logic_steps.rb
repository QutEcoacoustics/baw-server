# frozen_string_literal: true

placeholder :should do
  match(/should not|can't/) do
    false
  end

  match(/should|can/) do
    true
  end
end

placeholder :on_off do
  match(/disable|off/) do
    false
  end

  match(/enable|on/) do
    true
  end
end
