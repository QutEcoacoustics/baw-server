# frozen_string_literal: true

module SftpgoClient
  module Permission
    ALL = '*'
    LIST = 'list'
    DOWNLOAD = 'download'
    UPLOAD = 'upload'
    OVERWRITE = 'overwrite'
    DELETE = 'delete'
    RENAME = 'rename'
    CREATE_DIRS = 'create_dirs'
    CREATE_SYMLINKS = 'create_symlinks'
    CHMOD = 'chmod'
    CHOWN = 'chown'
    CHTIMES = 'chtimes'

    PERMISSIONS = Types::Coercible::String.default(ALL).enum(
      ALL,
      LIST,
      DOWNLOAD,
      UPLOAD,
      OVERWRITE,
      DELETE,
      RENAME,
      CREATE_DIRS,
      CREATE_SYMLINKS,
      CHMOD,
      CHOWN,
      CHTIMES
    )
  end
end
