# frozen_string_literal: true

module SftpgoClient
  module Permission
    # all permissions are granted
    ALL = '*'
    # list items is allowed
    LIST = 'list'
    # download files is allowed
    DOWNLOAD = 'download'
    # upload files is allowed
    UPLOAD = 'upload'
    # overwrite an existing file, while uploading, is allowed. upload permission is required to allow file overwrite
    OVERWRITE = 'overwrite'
    # delete files or directories is allowed
    DELETE = 'delete'
    # delete files is allowed
    DELETE_FILES = 'delete_files'
    # delete directories is allowed
    DELETE_DIRS = 'delete_dirs'
    # rename files or directories is allowed
    RENAME = 'rename'
    # rename files is allowed
    RENAME_FILES = 'rename_files'
    # rename directories is allowed
    RENAME_DIRS = 'rename_dirs'
    # create directories is allowed
    CREATE_DIRS = 'create_dirs'
    # create links is allowed
    CREATE_SYMLINKS = 'create_symlinks'
    #  changing file or directory permissions is allowed
    CHMOD = 'chmod'
    #  changing file or directory owner and group is allowed
    CHOWN = 'chown'
    #  changing file or directory access and modification time is allowed
    CHTIMES = 'chtimes'

    PERMISSIONS = Types::Coercible::String.default(ALL).enum(
      ALL,
      LIST,
      DOWNLOAD,
      UPLOAD,
      OVERWRITE,
      DELETE,
      DELETE_FILES,
      DELETE_DIRS,
      RENAME,
      RENAME_FILES,
      RENAME_DIRS,
      CREATE_DIRS,
      CREATE_SYMLINKS,
      CHMOD,
      CHOWN,
      CHTIMES
    )
  end
end
