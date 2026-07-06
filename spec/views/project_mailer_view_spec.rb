# frozen_string_literal: true

describe 'ProjectMailer views' do
  let(:sender_user) { create(:user) }
  let(:project) { create(:project) }

  it 'project access request email contains client URLs for project and permissions page' do
    message = ProjectMailer.project_access_request(sender_user, [project.id], 'testing')
    project_url = Settings.client_routes.project_url(project.id).to_s
    permissions_url = Settings.client_routes.project_permissions_url(project.id).to_s

    expect(message.body.decoded).to include(project_url, permissions_url)
  end
end
