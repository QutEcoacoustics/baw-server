# Changelog

## Unreleased

 - 2015-03-13
    - Small UI bug fixes
    - Added links to play audio and visualise projects and sites [#164](https://github.com/QutBioacoustics/baw-server/issues/164) [#172](https://github.com/QutBioacoustics/baw-server/issues/172)
    - Changed filter default items per page to 25 [#171](https://github.com/QutBioacoustics/baw-server/issues/171)
    - added ability to opt out of filter paging [#160](https://github.com/QutBioacoustics/baw-server/issues/160)
    - Made it more obvious that confirming an account involves checking email [#149](https://github.com/QutBioacoustics/baw-server/issues/149)

 - 2015-03-09
    - More changes to project and site pages [#164](https://github.com/QutBioacoustics/baw-server/issues/164)

 - 2015-03-08
    - Improved site lat/long obfuscation calculation [#91](https://github.com/QutBioacoustics/baw-server/issues/91)
    - Refactored permission code to prepare for project logged in and anon permissions (this was a quite large and sweeping change) [#99](https://github.com/QutBioacoustics/baw-server/issues/99)

 - 2015-03-07
    - Added last_seen_at column for users [#167](https://github.com/QutBioacoustics/baw-server/issues/167)
    - Added ability to disable paging for filters and enforced max item count [#160](https://github.com/QutBioacoustics/baw-server/issues/160)
    - Added foreign keys [#151](https://github.com/QutBioacoustics/baw-server/issues/151)
    - Added Timezone setting for sites and users [#116](https://github.com/QutBioacoustics/baw-server/issues/116)
    - Added links to visualise page [#155](https://github.com/QutBioacoustics/baw-server/issues/155)
    - Modify site show page to remove audio recording list [#164](https://github.com/QutBioacoustics/baw-server/issues/164)

## [Release 0.13.1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.13.1) (2015-03-02)

 - 2015-03-06
    - Fix: ignored ffmpeg warning for channel layout
    - Fix: case insensitive compare when chaning audio event tags
    - Added admin-only page to fix orphaned audio recordings [#153](https://github.com/QutBioacoustics/baw-server/issues/153)


 - 2015-02-28
    - Fix: site paging
    - Fix: Admin changing user's email [#158](https://github.com/QutBioacoustics/baw-server/issues/158)
    - Enhancement: additional user info for Admin [#159](https://github.com/QutBioacoustics/baw-server/issues/159)
    - Fix: error accessing sites/filter when logged in as Admin
    - Enhancement: added tests to ensure numbers in json are not quoted [#152](https://github.com/QutBioacoustics/baw-server/issues/152)

## [Release 0.13.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.13.0) (2015-02-20)

 - 2015-02-20
    - fixed problems with polling for media

 - 2015-02-07
    - added rake task to export audio recordings to csv

 - 2015-01-24
    - Fixed annotation library not filtering using query string parameters [#148](https://github.com/QutBioacoustics/baw-server/issues/148)

 - 2015-01-18
    - delete actions improved, archive headers added and fixed
    - standardised controller authorisation
    - added audio event filter action

 - 2015-01-06
    - Fixed CORS responses [#140](https://github.com/QutBioacoustics/baw-server/issues/140)
    - Added ability to poll Resque for job completion rather than polling filesystem.
    - Bug fix: added more strict validation and more tests for 'in' filter.

 - 2014-12-30
    - Upgraded to Rails 4.2.0.
    - Migrated from protected attributes to strong parameters.
    - Added `bin/setup` to ease setting up application.

 - 2014-12-29
    - fixed CORS configuration,including rspec tests. Requires new configuration setting: Settings.host.cors_origins. Uses rails-cors gem.
    - added rspec tests that ensure all endpoints are covered by rspec_api_documentation (commented out - not working yet).

## [Release 0.12.1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.12.1) (2014-12-16)

 - 2014-12-16: fixed problems with sign up form

## Started 2014-12-28.
