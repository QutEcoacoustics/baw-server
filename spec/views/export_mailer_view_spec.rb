# frozen_string_literal: true

describe 'ExportMailer views' do
  let(:creator) { create(:user) }
  let(:project) { create(:project, creator:) }
  let(:export) { create(:export, creator:, project:, expires_at: 1.day.from_now) }
  let(:message) { ExportMailer.completed_export_message(export) }

  it 'completed export message body says the export is completed and links to the project' do
    project_url = Settings.client_routes.project_url(project.id).to_s

    expect(message.body.decoded).to include('<strong>completed</strong>', project_url)
  end

  it 'completed export message body links to the export download with a token that finds the export' do
    token = message.body.decoded.gsub(/\s+/, '')[%r{exports/#{export.id}/download\?token=([^"<]+)}, 1]

    expect(Export.find_signed(token, purpose: :export_download)).to eq(export)
  end

  it 'sends the completed export message to the creator' do
    expect(message.to).to eq([creator.email])
  end

  it 'sends the completed export message to the creator and the required recipients without duplicates' do
    allow(Settings.actions.export).to receive(:required_recipients)
      .and_return(['required@example.com', creator.email])

    expect(message.to).to eq([creator.email, 'required@example.com'])
  end
end
