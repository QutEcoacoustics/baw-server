# Changelog

## Unreleased
 - 2016-08-03
   - Feature: Analysis Jobs items integration. Analysis jobs have been setup and their complete workflows tested and 
     integrated. See [#300](https://github.com/QutBioacoustics/baw-server/pull/300)
 - 2016-06-11
   - Feature: Analysis Jobs item tracking - basic support added for tracking each item in an analysis job [#290](https://github.com/QutBioacoustics/baw-server/pull/290)
   - Enhancement: Filter::Query can now have it's base query customised [931066b](https://github.com/QutBioacoustics/baw-server/commit/931066b5eb30925e34e659bdff91e5b55abce764)
 - 2016-04-24
    - Query string parameters for filter are merged with POST filter [#286](https://github.com/QutBioacoustics/baw-server/issues/286)
 - 2016-04-13
    - Added analysis_job_id and audio_recording_id to results API
 - 2016-04-06
    - Update db seeds, readme, and settings defaults
 - 2016-03-26
    - Allow markdown in description fields [#264](https://github.com/QutBioacoustics/baw-server/issues/264)
    - Update analysis result endpoint to normalise paths [#272](https://github.com/QutBioacoustics/baw-server/issues/272)
    - Convert to tzinfo identifier when rendering site and user json [#270](https://github.com/QutBioacoustics/baw-server/issues/270)
 - 2016-03-21
    - Changed analysis results 'model' size attribute to size_bytes and improved tests
 - 2016-03-18
    - allow owner to access site harvest and upload pages [#269](https://github.com/QutBioacoustics/baw-server/issues/269)
    - removed custom elements in analysis_job api [#267](https://github.com/QutBioacoustics/baw-server/issues/267)
    - fixed site location jitter [#266](https://github.com/QutBioacoustics/baw-server/issues/266)
 - 2016-03-14
    - Updated harvest.yml with notes and safer defaults
 - 2016-03-04
    - Expose `sites.tzinfo_tz` field in API [#262](https://github.com/QutBioacoustics/baw-server/issues/262)
 - 2016-03-03
    - improved filter settings validation
 - 2016-03-02
    - Add calculated field recorded_end_date to AudioRecording's filter options [#261](https://github.com/QutBioacoustics/baw-server/issues/261)
 - 2016-02-27
    - Added overall_data_length_bytes to analysis_job [#256](https://github.com/QutBioacoustics/baw-server/issues/256)
    - Also reworked analysis_job lifecycle up to enqueing resque jobs to be more obvious.
    - All analysis_job attributes are now available in api.
    - scripts#index is restricted to only most recent version in each script group [#259](https://github.com/QutBioacoustics/baw-server/issues/259)
    - Added CustomErrors::OrphanedSiteError so it is more obvious [#252](https://github.com/QutBioacoustics/baw-server/issues/252)
 - 2016-02-26
    - added basic admin list and view for analysis jobs
    - Added executable_settings_media_type to scripts table. Exposed scripts#show. [#258](https://github.com/QutBioacoustics/baw-server/issues/258) [#259](https://github.com/QutBioacoustics/baw-server/issues/259)
 - 2016-02-20
    - partial fix for sorting by calculated fields - some inital queries still include sorting [#254](https://github.com/QutBioacoustics/baw-server/issues/254) 
    - potential fix for problems with filtering by calculated fields [#145](https://github.com/QutBioacoustics/baw-server/issues/145)
    - fixed `/taggings/filter` - it was present, but naming mismatches were causing errors
 - 2016-02-19
    - refactor specs to be more obvious about what they do and where various functionality is located
    - Add ability to filter audio recordings based on project attributes [#253](https://github.com/QutBioacoustics/baw-server/issues/253)
 - 2016-02-18
    - check for divide by 0, closes [#251](https://github.com/QutBioacoustics/baw-server/issues/251)

## [Release 0.18.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.18.0) (2016-02-06)

 - 2016-02-06
   - (chore) added support for Vagrant workflows. Development environments are not setup automatically. [commits](https://github.com/QutBioacoustics/baw-server/compare/814a90e44b635addde83568e01cf8e4ed23a2f8b...e292a2241e14c5374d2fddb1ea9b58e1fd2ab29b)
 - 2016-01-15
   - paging meta data fixed when `disable_paging` option is set [#248](https://github.com/QutBioacoustics/baw-server/issues/248)
 - 2016-01-13
   - fixed errors for `AudioRecording.notes` field normalization script [commits](https://github.com/QutBioacoustics/baw-server/compare/8f6d356df3df35a6629e32212698aed0992abcea...e984ccfe0cd8737262c8550cec577d435ac1d366)
 - 2016-01-12
   - filenames for media downloads are fixed [#247](https://github.com/QutBioacoustics/baw-server/issues/247)
 - 2015-12-20
   - disabled email notifications for not found errors [#245](https://github.com/QutBioacoustics/baw-server/issues/245)
   - filter out dotfiles from analysis job dir list [#244](https://github.com/QutBioacoustics/baw-server/issues/244)
 - 2015-11-22
    - analysis job api is no longer recursive [#196](https://github.com/QutBioacoustics/baw-server/issues/196)
    - Added an option to download the annotations CSV files with a custom timezone offset [#240](https://github.com/QutBioacoustics/baw-server/issues/240)
 - 2015-11-01
    - Added link to download annotations created by a user, and a list of annotation download links per site [#233](https://github.com/QutBioacoustics/baw-server/issues/233)

 - 2015-09-04
    - removed dataset model [#189](https://github.com/QutBioacoustics/baw-server/issues/189)
    - updated job model [#191](https://github.com/QutBioacoustics/baw-server/issues/191)
    - updated script model [#190](https://github.com/QutBioacoustics/baw-server/issues/190)
    - created saved search model [#199](https://github.com/QutBioacoustics/baw-server/issues/199)
    - created way to generate job items from a job and saved search [#198](https://github.com/QutBioacoustics/baw-server/issues/198)
    - updated analysis endpoint [#196](https://github.com/QutBioacoustics/baw-server/issues/196)
    - added directory listing to analysis endpoint [#208](https://github.com/QutBioacoustics/baw-server/issues/208)
    - major overhaul of controller model loading and authorization
    - updated all rspec tests to use current method of checking json responses
    - all relevant endpoints now use the [API spec](https://github.com/QutBioacoustics/baw-server/wiki/Rails-API-Spec)

## [Release 0.17.1-1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.17.1-1) (2015-09-28)

 - 2015-09-28
    - hotfix to change client urls

## [Release 0.17.1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.17.1) (2015-08-19)

 - 2015-08-19
    - removed gmaps4rails in favour of plain google maps
    - added indexes for file_hash, uuid, and id to audio_recordings table to improve performance

## [Release 0.17.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.17.0) (2015-08-17)

 - 2015-08-16
    - More UI changes to sync with baw-client UI 
 - 2015-08-10
    - Updated website navigation bar
 - 2015-08-08
    - Changed audio tool defaults for media and timeouts
    - Fix duplication due to projects-sites many to many relation [#226](https://github.com/QutBioacoustics/baw-server/issues/226) [#219](https://github.com/QutBioacoustics/baw-server/issues/219)

 - 2015-07-31
    - Updated bootstrap from v2.3 to v3.3 [#133](https://github.com/QutBioacoustics/baw-server/issues/133)
    - Changes to Harvesting and Audio pages [#228](https://github.com/QutBioacoustics/baw-server/issues/228)
    - Improvements to annotation download csv [#227](https://github.com/QutBioacoustics/baw-server/issues/227)

 - 2015-07-26
    - Fixed a bug in `user_accounts#filter`: it tried to access model attributes that weren't loaded

 - 2015-07-08
    - Changes to media polling to reduce the number of errors raised. 

 - 2015-07-06
    - enable sorting on custom fields [#220](https://github.com/QutBioacoustics/baw-server/issues/220)
    - fixed site page loading slowly [#222](https://github.com/QutBioacoustics/baw-server/issues/222)
    - attempted to fix media polling issues, still unresolved [#217](https://github.com/QutBioacoustics/baw-server/issues/217)
    - update user_accounts endpoint to API spec [#223] (https://github.com/QutBioacoustics/baw-server/issues/223)

 - 2015-06-27
    - Removed taggings that were included in the tags filter [#218](https://github.com/QutBioacoustics/baw-server/issues/218)
    - Changed access query to use Arel instead of ActiveRecord due to regression in ActiveRecord 4.2.3.

## [Release 0.15.1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.15.1) (2015-06-16)

 - 2015-06-15
    - added `:tag_id` to taggings for `audio_event`.

 - 2015-06-14
    - bug fix for tags filter [#210](https://github.com/QutBioacoustics/baw-server/issues/210)
    - bug fix for audio recording overlap check (again) More information provided on error. [#184](https://github.com/QutBioacoustics/baw-server/issues/184)
    - Harvester endpoints converted to standard API.
    - Normalised error responses.
    - Using new analysis paths, see QutBioacoustics/baw-workers#20

## [Release 0.15.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.15.0) (2015-06-10)

 - 2015-06-08
    - change annotation csv download to a flat result set [#204](https://github.com/QutBioacoustics/baw-server/issues/204)
    - added upload instructions page [#186](https://github.com/QutBioacoustics/baw-server/issues/186)
    - added ability to redirect after logging in and fixed some Devise issues [#205](https://github.com/QutBioacoustics/baw-server/issues/205)

 - 2015-06-06
    - Provide distinct urls for different error pages for the client app [#206](https://github.com/QutBioacoustics/baw-server/issues/206)

 - 2015-05-10
    - project and site names can be longer [#177](https://github.com/QutBioacoustics/baw-server/issues/177)
    - modified nav bar links [#178](https://github.com/QutBioacoustics/baw-server/issues/178)

 - 2015-04-29
    - CSRF check disabled for api requests authenticated using a token
    - more strict checks for media request parameters [#187](https://github.com/QutBioacoustics/baw-server/issues/187)

 - 2015-04-26
    - Improved audio recording overlap check [#184](https://github.com/QutBioacoustics/baw-server/issues/184)
    - removed obsolete access level class
    - swapped .where(1 = 0) for .none
    - added zonebie for testing and updated gems

 - 2015-04-18
    - Fixes #168 by Responds with a head response on media generation error [#168] (https://github.com/QutBioacoustics/baw-server/issues/168)
    - Resque polling returns more information
    - Added X-Error-Type and X-Archived-At to CORS allowed headers
    - ensure harvester can log in after enabling CSRF for api

 - 2015-04-02
    - Added controller, views, and routes for managing tags for [#175](https://github.com/QutBioacoustics/baw-server/issues/175)

 - 2015-03-29
    - Added page to assign sites to a project [#153](https://github.com/QutBioacoustics/baw-server/issues/153)
    - added commented changes for logged_in and anonymous access [#99](https://github.com/QutBioacoustics/baw-server/issues/99)

 - 2015-03-28
    - Many to many associations will now include the ids or full information from the join table [#181](https://github.com/QutBioacoustics/baw-server/issues/181)
    - Enabled CSRF protection for API

## [Release 0.14.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.14.0) (2015-03-22)

 - 2015-03-22
    - Removed audio event library endpoint [#128](https://github.com/QutBioacoustics/baw-server/issues/128)
    - Added ability to filter by calculated fields

 - 2015-03-17
    - Enhancement: filter api now supports filtering by neighbouring models [#176](https://github.com/QutBioacoustics/baw-server/issues/176)

 - 2015-03-16
    - Regression fixed: paging link format [#169](https://github.com/QutBioacoustics/baw-server/issues/169)
    - Regression fixed: Projections options now respected [#170](https://github.com/QutBioacoustics/baw-server/issues/170)

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
