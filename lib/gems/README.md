# Layout of gems directory

Each directory in the `gems` folder could nominally be it's own repository.

Thus they are laid out as if they were git sub modules.

The first directory should be a snake-cased name for the module. This name is
ignored by the autoloader. The name should be as if it were the reo name on GitHub

The next level directory is the `lib` folder. The contents of these directories are treated
like root namespaces.

After that, zeitwerk rules for module naming should apply.