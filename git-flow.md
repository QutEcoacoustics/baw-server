# Git Flow

Based on [A successful Git branching model By Vincent Driessen](http://nvie.com/posts/a-successful-git-branching-model/).

## Making changes

All changes go in feature branches.

1. Ensure all changes are committed and pushed to `origin`.
1. Checkout `develop` branch: `git checkout develop`
1. Run tests: `bundle exec guard`
1. Fix any failing tests.
1. Create a new branch: `git checkout -b feature-<branch name> develop`
1. Make the (hopefully small) changes to implement the feature.
1. Record changes in CHANGELOG.md.
1. Commit the changes: `git add`, `git commit`
1. **OPTIONAL: branch does not have to be pushed to remote** Push the develop branch to `origin`: `git push -u origin feature-<branch name>`

### Merging changes

1. Checkout develop: `git checkout develop`
1. Merge changes into `develop`: `git merge --no-ff feature-<branch name>`
1. Run tests: `bundle exec guard` `<enter>`. Fix any failing tests.
1. Delete feature branch locally: `git branch -d feature-<branch name>`
1. **OPTIONAL: only needs to be deleted if the branch was pushed to remote** Delete feature branch remotely: `git push origin --delete feature-<branch name>`
1. Push the merges to `origin`: `git push`

## Releasing a new version of baw-server to Github

1. Ensure all changes are committed and pushed to `origin`.
1. Checkout `develop` branch: `git checkout develop`
1. Run tests: `bin/rspec`
1. Fix any failing tests.
1. Create a new branch: `git checkout -b release-<version> develop`
1. Change the version numbers in `app/models/settings.rb`
1. Check for newer versions of gems: `bundle outdated`. Update in Gemfile if necessary.
1. Check for newer versions of gems from Github in Gemfile. Update commit reference if necessary.
1. Commit the changes: `git commit -am "increment version to <version>"`
1. Update [CHANGELOG.md](./CHANGELOG.md) to add new release and list of changes that were not released.
1. **OPTIONAL: branch does not have to be pushed to remote** Push the release branch to `origin`: `git push -u origin release-<version>`
1. Checkout master: `git checkout master`
1. Merge changes into `master`: `git merge --no-ff release-<version>`
1. Create tag: `git tag -a <version>`
1. Checkout `develop` branch: `git checkout develop`
1. Merge changes into `develop`: `git merge --no-ff release-<version>`
1. Run tests: `bin/rspec`. Fix any failing tests.
1. Delete release branch locally: `git branch -d release-<version>`
1. **OPTIONAL: only needs to be deleted if the branch was pushed to remote** Delete release branch remotely: `git push origin --delete release-<version>`
1. Push the new tag to `origin`: `git push --tags`
1. Push the merges to `origin`: `git push`

### Summarised

```
git checkout develop
bin/rspec
git checkout -b release-<version> develop
# change version numbers: app/models/settings.rb
bundle outdated
# update gems, commit if changed
git commit -am "increment version to <version>"
# update CHANGELOG.md
git checkout master
git merge --no-ff release-<version>
git tag -a <version>
git checkout develop
git merge --no-ff release-<version>
git push --tags
git push
```

