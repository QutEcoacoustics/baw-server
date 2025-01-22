# frozen_string_literal: true

describe 'Scripts' do
  prepare_users

  it 'can insert a new script' do
    provenance = create(:provenance)

    params = {
      script: {
        name: 'new script',
        description: 'new description',
        analysis_identifier: 'new-script',
        version: '1.0.0',
        verified: true,
        executable_command: 'echo "hello world {source_dir} {output_dir}"',
        executable_settings: 'setting: 1.0',
        executable_settings_media_type: 'application/yaml',
        executable_settings_name: 'settings.yaml',
        provenance_id: provenance.id,
        event_import_glob: '*.csv',
        resources: {
          ncpus: 1
        }
      }
    }

    post '/admin/scripts', params:, **api_with_body_headers(admin_token)

    expect_success
    script = Script.find(api_data[:id])

    expect(script.verified).to be_truthy
  end

  it 'can update a script (but really it is an insert)' do
    script = create(:script)

    params = {
      script: {
        name: 'new name',
        description: 'new description',
        analysis_identifier: 'new-script',
        version: '1.0.0',
        verified: true,
        executable_command: 'echo "hello world {source_dir} {output_dir}"',
        executable_settings: 'setting: 1.0',
        executable_settings_media_type: 'application/yaml',
        executable_settings_name: 'settings.yaml',
        provenance_id: script.provenance.id,
        resources: {
          ncpus: 1
        }
      }
    }

    post "/admin/scripts/#{script.id}", params: params, **api_with_body_headers(admin_token)

    expect_success
    new_script = Script.find(api_data[:id])

    expect(new_script.name).to eq('new name')
    expect(new_script.version).to eq(script.version + 1)
    expect(new_script.id).not_to eq(script.id)
    expect(new_script.group_id).to eq(script.group_id)
  end
end
