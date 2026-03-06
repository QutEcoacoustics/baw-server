# frozen_string_literal: true

require_migration!

describe ConvertScriptCommandsToLiquidSyntax, :migration do
  let(:users_table) { table(:users) }
  let(:scripts_table) { table(:scripts) }

  before do
    user = users_table.create!(
      user_name: 'migration-user',
      email: 'migration@example.com',
      encrypted_password: 'password'
    )

    scripts_table.create!(
      name: 'old placeholders',
      analysis_identifier: 'old_placeholders',
      version: 1,
      creator_id: user.id,
      created_at: Time.zone.now,
      executable_command: 'run {source} --output "{output_dir}"',
      executable_settings: ''
    )

    scripts_table.create!(
      name: 'ignore existing liquid',
      analysis_identifier: 'already_liquid',
      version: 1,
      creator_id: user.id,
      created_at: Time.zone.now,
      executable_command: 'run {{source}} --output {{output_dir}}',
      executable_settings: ''
    )
  end

  it 'converts historical executable command placeholders to liquid placeholders' do
    migrate!

    placeholders = scripts_table.find_by!(analysis_identifier: 'old_placeholders')
    already_liquid = scripts_table.find_by!(analysis_identifier: 'already_liquid')

    expect(placeholders.executable_command).to eq('run {{source}} --output "{{output_dir}}"')
    expect(already_liquid.executable_command).to eq('run {{source}} --output {{output_dir}}')
  end
end
