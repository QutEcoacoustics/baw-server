# Layout of gems directory

Each directory in the `gems` folder could nominally be it's own repository.

Thus they are laid out as if they were git sub modules.

The first directory should be a snake-cased name for the module. This name is
ignored by the autoloader. The name should be as if it were the repo name on GitHub

The next level directory is the `lib` folder. The contents of these directories are treated
like root namespaces.

After that, zeitwerk rules for module naming should apply.

# SFTPGO Bindings

We use sftpgo to set up temporary upload accounts per harvest.

The code in `./sftpgo_generated_client` is generated and should NOT be modified by hand.
The script that does this generation is in `provision/sftpgo_schema_generation.sh`.
