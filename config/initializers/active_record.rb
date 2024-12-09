# frozen_string_literal: true

ActiveRecord::SchemaDumper.ignore_tables = [
  'sftpgo_admins',
  'sftpgo_admins_id_seq',
  'sftpgo_api_keys',
  'sftpgo_api_keys_id_seq',
  'sftpgo_defender_events',
  'sftpgo_defender_events_id_seq',
  'sftpgo_defender_hosts',
  'sftpgo_defender_hosts_id_seq',
  'sftpgo_folders',
  'sftpgo_folders_id_seq',
  'sftpgo_folders_mapping',
  'sftpgo_folders_mapping_id_seq',
  'sftpgo_schema_version',
  'sftpgo_schema_version_id_seq',
  'sftpgo_shares',
  'sftpgo_shares_id_seq',
  'sftpgo_users',
  'sftpgo_users_id_seq'
]
