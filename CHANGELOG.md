# Changelog

## Unreleased

 - 2015-03-07
   - Added last_seen_at column for users (#167)
   - Added ability to disable paging for filters and enforced max item count (#160)
   - Added foreign keys (#151)
   - Added Timezone setting for sites and users (#116)
   - Added links to visualise page (#164)

## [Release 0.13.1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.13.1) (2015-03-02)

 - 2015-03-06
   - Fix: ignored ffmpeg warning for channel layout
   - Fix: case insensitive compare when chaning audio event tags

 - 2015-02-28
   - Fix: site paging
   - Fix: Admin changing user's email
   - Enhancement: additional user info for Admin
   - Fix: error accessing sites/filter when logged in as Admin
   - Enhancement: added tests to ensure numbers in json are not quoted

## [Release 0.13.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.13.0) (2015-02-20)

 - 2015-02-20
    - fixed problems with polling for media

 - 2015-02-07
    - added rake task to export audio recordings to csv

 - 2015-01-24
    - Fixed annotation library not filtering using query string parameters.

 - 2015-01-18
    - delete actions improved, archive headers added and fixed
    - standardised controller authorisation
    - added audio event filter action

 - 2015-01-06
    - Fixed CORS responses.
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
