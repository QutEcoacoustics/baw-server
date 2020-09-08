CMS comes with a seed importer that imports a file structure from this
directory. However, it overwrites seeds in the database if the seed file is
newer than the db entry, and also clears out extra db entries that are not in
this seeds directory - a destructive operation.

I wanted seeds that we could run every time we deploy to ensure consistency.
Thus I've skipped using the CMS importer and instead run the `cms_seeds.rb` file
which only adds entries into the database if they are missing.

The code in `cms_seeds.rb` runs after every invocation of `rake db:seed`.
See lib/tasks/cms_seed.rake for the glue that makes this work.

