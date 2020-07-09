# lib

Should contain related code to the app, but should not contain any code
that needs to be autoloaded!

Autoloaded app-related code should be placed in the `app` directory.
Code that does not fit elsewhere should be placed in `app/modules`.

If the code is not to be autoloaded then place it here in `lib`.

- `gems` contains whole(ish) libraries that could be extracted as gems but which
  for some reason we've chosen to incorporate into this repository.
- `patches` contains code run once on application boot. See `config/application.rb`.
- `tasks` contain rake tasks - these files are not part of the app per se, but
  rather use the app in some meta-fashion.