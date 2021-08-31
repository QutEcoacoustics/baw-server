# Changelog

## [4.6.1](https://github.com/QutEcoacoustics/baw-server/tree/4.6.1) (2021-08-31)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.6.0...4.6.1)

## [4.6.0](https://github.com/QutEcoacoustics/baw-server/tree/4.6.0) (2021-08-31)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.1.0...4.6.0)

**Implemented enhancements:**

- Add media stats tracking [\#525](https://github.com/QutEcoacoustics/baw-server/issues/525)
- Region image urls [\#497](https://github.com/QutEcoacoustics/baw-server/issues/497)
- Performance enhancements for Media polling [\#329](https://github.com/QutEcoacoustics/baw-server/issues/329)
-  Adds media download statistics tracking  [\#530](https://github.com/QutEcoacoustics/baw-server/pull/530) ([atruskie](https://github.com/atruskie))
- Additional statistics [\#529](https://github.com/QutEcoacoustics/baw-server/pull/529) ([Allcharles](https://github.com/Allcharles))
- Fixes stats page and adds stats endpoint [\#524](https://github.com/QutEcoacoustics/baw-server/pull/524) ([atruskie](https://github.com/atruskie))
- Move status endpoint to dedicated controller [\#522](https://github.com/QutEcoacoustics/baw-server/pull/522) ([atruskie](https://github.com/atruskie))

**Fixed bugs:**

- Partial writes for media cache causing errors [\#527](https://github.com/QutEcoacoustics/baw-server/issues/527)
- Bug: A BawWorkers::ActiveJob::EnqueueError occurred in media\#show: [\#526](https://github.com/QutEcoacoustics/baw-server/issues/526)
- website\_status page broken [\#523](https://github.com/QutEcoacoustics/baw-server/issues/523)
- Changes to support dev work [\#518](https://github.com/QutEcoacoustics/baw-server/issues/518)
- Resolve resque polling errors [\#217](https://github.com/QutEcoacoustics/baw-server/issues/217)
- Decouples spectrogram generation from audio generation [\#528](https://github.com/QutEcoacoustics/baw-server/pull/528) ([atruskie](https://github.com/atruskie))

**Closed issues:**

- Missing statistics route [\#413](https://github.com/QutEcoacoustics/baw-server/issues/413)

## [4.1.0](https://github.com/QutEcoacoustics/baw-server/tree/4.1.0) (2021-07-16)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.0.4...4.1.0)

**Fixed bugs:**

- Media generation bug: An Errno::ENOENT occurred in media\#show: [\#521](https://github.com/QutEcoacoustics/baw-server/issues/521)

## [4.0.4](https://github.com/QutEcoacoustics/baw-server/tree/4.0.4) (2021-07-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.0.3...4.0.4)

## [4.0.3](https://github.com/QutEcoacoustics/baw-server/tree/4.0.3) (2021-07-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.0.2...4.0.3)

## [4.0.2](https://github.com/QutEcoacoustics/baw-server/tree/4.0.2) (2021-07-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.0.1...4.0.2)

## [4.0.1](https://github.com/QutEcoacoustics/baw-server/tree/4.0.1) (2021-07-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.0.0...4.0.1)

## [4.0.0](https://github.com/QutEcoacoustics/baw-server/tree/4.0.0) (2021-07-07)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/3.0.4...4.0.0)

## [3.0.4](https://github.com/QutEcoacoustics/baw-server/tree/3.0.4) (2021-05-11)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/3.0.3...3.0.4)

## [3.0.3](https://github.com/QutEcoacoustics/baw-server/tree/3.0.3) (2021-05-11)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/3.0.2...3.0.3)

**Closed issues:**

- Missing account routes [\#439](https://github.com/QutEcoacoustics/baw-server/issues/439)
- User accounts route with admin permissions [\#421](https://github.com/QutEcoacoustics/baw-server/issues/421)

## [3.0.2](https://github.com/QutEcoacoustics/baw-server/tree/3.0.2) (2020-10-14)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/3.0.1...3.0.2)

**Implemented enhancements:**

- Add content management system [\#492](https://github.com/QutEcoacoustics/baw-server/issues/492)
- Remove custom\_longitude/latitude values [\#489](https://github.com/QutEcoacoustics/baw-server/issues/489)
- Project short descriptions [\#486](https://github.com/QutEcoacoustics/baw-server/issues/486)
- Tracking site issues [\#477](https://github.com/QutEcoacoustics/baw-server/issues/477)
- Missing admin orphan sites route [\#430](https://github.com/QutEcoacoustics/baw-server/issues/430)
- Project route missing fields [\#425](https://github.com/QutEcoacoustics/baw-server/issues/425)
- Create site route ignoring inputs [\#410](https://github.com/QutEcoacoustics/baw-server/issues/410)
- Make site terminology customiseable [\#383](https://github.com/QutEcoacoustics/baw-server/issues/383)
- Add docs generation to CI build [\#367](https://github.com/QutEcoacoustics/baw-server/issues/367)
- Fixes cut speed for ffmpeg [\#498](https://github.com/QutEcoacoustics/baw-server/pull/498) ([atruskie](https://github.com/atruskie))
- Adds an upload service [\#494](https://github.com/QutEcoacoustics/baw-server/pull/494) ([atruskie](https://github.com/atruskie))
- Standardizes description markdown conversion in API [\#488](https://github.com/QutEcoacoustics/baw-server/pull/488) ([atruskie](https://github.com/atruskie))

**Fixed bugs:**

- Model description html markup [\#487](https://github.com/QutEcoacoustics/baw-server/issues/487)
- Some site fields are not exposed in the API [\#406](https://github.com/QutEcoacoustics/baw-server/issues/406)

**Closed issues:**

- Slow points when harvesting [\#212](https://github.com/QutEcoacoustics/baw-server/issues/212)

**Merged pull requests:**

- Adds a CMS [\#493](https://github.com/QutEcoacoustics/baw-server/pull/493) ([atruskie](https://github.com/atruskie))
- Adds regions and active storage [\#491](https://github.com/QutEcoacoustics/baw-server/pull/491) ([atruskie](https://github.com/atruskie))
- Bump kramdown from 2.2.1 to 2.3.0 [\#485](https://github.com/QutEcoacoustics/baw-server/pull/485) ([dependabot[bot]](https://github.com/apps/dependabot))

## [3.0.1](https://github.com/QutEcoacoustics/baw-server/tree/3.0.1) (2020-08-06)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/3.0.0.0...3.0.1)

## [3.0.0.0](https://github.com/QutEcoacoustics/baw-server/tree/3.0.0.0) (2020-07-29)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/2.0.1...3.0.0.0)

**Implemented enhancements:**

- Missing site model details [\#453](https://github.com/QutEcoacoustics/baw-server/issues/453)
- Missing tags parameters [\#436](https://github.com/QutEcoacoustics/baw-server/issues/436)
- Missing generic sites route [\#431](https://github.com/QutEcoacoustics/baw-server/issues/431)
- Implement Progress API [\#348](https://github.com/QutEcoacoustics/baw-server/issues/348)
- Update database schema to accommodate citizen science [\#346](https://github.com/QutEcoacoustics/baw-server/issues/346)
- Allow removing an image from a site or project [\#315](https://github.com/QutEcoacoustics/baw-server/issues/315)
- Systematic check of dates & times, ensuring timezone formatting [\#279](https://github.com/QutEcoacoustics/baw-server/issues/279)
- By permission keyword arguments [\#481](https://github.com/QutEcoacoustics/baw-server/pull/481) ([Allcharles](https://github.com/Allcharles))
- Basic shallow site routes [\#478](https://github.com/QutEcoacoustics/baw-server/pull/478) ([Allcharles](https://github.com/Allcharles))
- PR Template [\#476](https://github.com/QutEcoacoustics/baw-server/pull/476) ([Allcharles](https://github.com/Allcharles))
- Rename taxanomic to taxonomic [\#475](https://github.com/QutEcoacoustics/baw-server/pull/475) ([Allcharles](https://github.com/Allcharles))
- Upgrades to Rails 6 [\#470](https://github.com/QutEcoacoustics/baw-server/pull/470) ([atruskie](https://github.com/atruskie))
- Missing tag model details [\#465](https://github.com/QutEcoacoustics/baw-server/pull/465) ([Allcharles](https://github.com/Allcharles))
- Missing site model details [\#463](https://github.com/QutEcoacoustics/baw-server/pull/463) ([Allcharles](https://github.com/Allcharles))
- Media public access and tests [\#404](https://github.com/QutEcoacoustics/baw-server/pull/404) ([atruskie](https://github.com/atruskie))

**Fixed bugs:**

- Tag model is\_taxonomic spelling mistake [\#466](https://github.com/QutEcoacoustics/baw-server/issues/466)
- New tag API route missing notes input [\#464](https://github.com/QutEcoacoustics/baw-server/issues/464)
- A NoMethodError occurred in errors\#route\_error: [\#405](https://github.com/QutEcoacoustics/baw-server/issues/405)
- Incorrect current page link when there are zero items  [\#378](https://github.com/QutEcoacoustics/baw-server/issues/378)
- paging links not working on get filter requests [\#376](https://github.com/QutEcoacoustics/baw-server/issues/376)
- Incorrect default order for dataset items [\#368](https://github.com/QutEcoacoustics/baw-server/issues/368)
- Bug: NoMethodError occurred in dataset\_items\#create [\#366](https://github.com/QutEcoacoustics/baw-server/issues/366)
- Add better error messages for bad content type headers [\#361](https://github.com/QutEcoacoustics/baw-server/issues/361)
- CSV export for annotations includes leading spaces in headers [\#340](https://github.com/QutEcoacoustics/baw-server/issues/340)
- Timezone hour:minutes display to the right of timezone name appears to be formatted incorrectly [\#336](https://github.com/QutEcoacoustics/baw-server/issues/336)
- Exception when determining access permissions to a site [\#333](https://github.com/QutEcoacoustics/baw-server/issues/333)

**Closed issues:**

- Missing assign sites route [\#447](https://github.com/QutEcoacoustics/baw-server/issues/447)
- Missing annotations route [\#445](https://github.com/QutEcoacoustics/baw-server/issues/445)
- Missing type of tag route [\#441](https://github.com/QutEcoacoustics/baw-server/issues/441)
- Missing bookmarks route [\#440](https://github.com/QutEcoacoustics/baw-server/issues/440)
- Failing sites filter route [\#437](https://github.com/QutEcoacoustics/baw-server/issues/437)
- Alternative route for progress events that does not require a dataset\_item\_id [\#371](https://github.com/QutEcoacoustics/baw-server/issues/371)
- Remove timezone configuration for brisbane [\#24](https://github.com/QutEcoacoustics/baw-server/issues/24)

**Merged pull requests:**

- Adds an automatic changelog generator [\#483](https://github.com/QutEcoacoustics/baw-server/pull/483) ([atruskie](https://github.com/atruskie))
- Bump json from 1.8.6 to 2.3.1 [\#482](https://github.com/QutEcoacoustics/baw-server/pull/482) ([dependabot[bot]](https://github.com/apps/dependabot))
- Rswag - adds the ability to generate documentation for the API [\#479](https://github.com/QutEcoacoustics/baw-server/pull/479) ([atruskie](https://github.com/atruskie))
- Bump rack from 1.4.1 to 2.2.3 in /lib/gems/resque-status [\#473](https://github.com/QutEcoacoustics/baw-server/pull/473) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump nokogiri from 1.6.1 to 1.10.10 in /lib/gems/resque-status [\#472](https://github.com/QutEcoacoustics/baw-server/pull/472) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rake from 10.1.1 to 13.0.1 in /lib/gems/resque-status [\#471](https://github.com/QutEcoacoustics/baw-server/pull/471) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rack from 1.6.11 to 1.6.12 [\#422](https://github.com/QutEcoacoustics/baw-server/pull/422) ([dependabot[bot]](https://github.com/apps/dependabot))
- Citizen science [\#381](https://github.com/QutEcoacoustics/baw-server/pull/381) ([peichins](https://github.com/peichins))
- removed leading space in csv column header names [\#379](https://github.com/QutEcoacoustics/baw-server/pull/379) ([peichins](https://github.com/peichins))
- Feature progress events endpoints [\#372](https://github.com/QutEcoacoustics/baw-server/pull/372) ([peichins](https://github.com/peichins))
- Checks that post params is not empty for update and create [\#369](https://github.com/QutEcoacoustics/baw-server/pull/369) ([peichins](https://github.com/peichins))

# Old Changelog

## [Release 2.0.1](https://github.com/QutBioacoustics/baw-server/releases/tag/2.0.1)

- 2018-03-27
  - Media defaults to native sample rate when filtering out invalid available objects
    See [#363](https://github.com/QutEcoacoustics/baw-server/pull/363)


## [Release 2.0.0](https://github.com/QutBioacoustics/baw-server/releases/tag/2.0.0)

- 2018-03-26
  - Adds support for more sample rates in media generation. Now the recording's native sample rate is always allowed,
    and support for returning 96 kHz files has been added. Note, this change requires a breaking change in the Media
    REST API, hence the major version bump. We have reviewed our code and have found no code that was dependent on the
    changes so we anticipate no breakage. Special mention to [@peichins](https://github.com/peichins) for the hard work
    required for this change.
    See [#351](https://github.com/QutEcoacoustics/baw-server/issues/351)


## [Release 1.6.2](https://github.com/QutBioacoustics/baw-server/releases/tag/1.6.2)

- 2018-03-13
  - Fixes more bugs bugs with original file download.
    See [f5ceb7e](https://github.com/QutEcoacoustics/baw-server/commit/f5ceb7e2f9d7e63b47d2f91740b44e27690ffefa)

## [Release 1.6.1](https://github.com/QutBioacoustics/baw-server/releases/tag/1.6.1)

- 2018-03-12
  - Fixes bug with original file download
    See [#358](https://github.com/QutEcoacoustics/baw-server/issues/358)
  - Adds support for Datasets and DatasetItems. These are disjoint collections of audio recording
    segments that can be analyzed or processed in a sequence. This has been done to support the CS
    use case.
    See [#352](https://github.com/QutEcoacoustics/baw-server/pull/352)

## [Release 1.5.1](https://github.com/QutBioacoustics/baw-server/releases/tag/1.5.1)

- 2018-02-27
  - Hacky patch to try and fix bugs with sqlite-serve.
    See [5f6bc21](https://github.com/QutEcoacoustics/baw-server/commit/5f6bc21cd73736156c8f6429a7ae022747c02585)
- 2018-02-26
  - Adds the ability for Admin or Harvester users to download full original audio files.
    See [#353](https://github.com/QutEcoacoustics/baw-server/issues/353)

## [Release 1.4.0](https://github.com/QutBioacoustics/baw-server/releases/tag/1.4.0)

- 2018-02-21
  - baw-server can now serve analysis result items from SQLite 3 files. This functionality will be used to
    serve zooming spectrogram image tiles. See:
    - [da5f35f](https://github.com/QutEcoacoustics/baw-server/commit/da5f35f7778ce8e4ad0986861c77ee375845b05f)
    - [94cd57b](https://github.com/QutEcoacoustics/baw-server/commit/94cd57bb8be33913092585a941d2aacee044e096)
    - [32e6cdd](https://github.com/QutEcoacoustics/baw-server/commit/32e6cdd702508f6ccf72de7d4264e82754dff2ff)
    - [571f136](https://github.com/QutEcoacoustics/baw-server/commit/571f136f8cbc1fdb2e23891310afae64dbe43294)
    - [ea9e1d7](https://github.com/QutEcoacoustics/baw-server/commit/ea9e1d7f86c385b7f2f532e580de9d2f62480c25)
- 2018-01-13
  - Add models and migrations for Datasets, DatasetItems, and ProgressEvents.
    See [#349](https://github.com/QutEcoacoustics/baw-server/pull/349)

## [Release 1.3.0](https://github.com/QutBioacoustics/baw-server/releases/tag/1.3.0)

- 2017-03-16
    - Fixed feature tests for permissions page
    See [fd0316d](https://github.com/QutBioacoustics/baw-server/commit/fd0316dc04cf2ed5d8a9fb111dcbb30ea69da6e3)
    - Reorders columns for small layout scenarios
    See [fab0709](https://github.com/QutBioacoustics/baw-server/commit/fab0709481400656fcc97b416da2872b77b3bc8c)
    -  Adds alphabetical paging to permissions page
    See [b32494a](https://github.com/QutBioacoustics/baw-server/commit/b32494a61c3c1e43f5b13fc82346f7e8865dc721)
    - Created an alphabetical pager
    See [cdcdd3d](https://github.com/QutBioacoustics/baw-server/commit/cdcdd3d0aa31e625cfca077ad8c539026524fe29)
    - Standardizes project card rendering
    See [52f17c8](https://github.com/QutBioacoustics/baw-server/commit/52f17c8f04944d635b1c3a3ff15133702bc99a51)
    - Added ability to render simplified markdown
    See [1c778d0](https://github.com/QutBioacoustics/baw-server/commit/1c778d05e5165cb89505c30b8272c47380926346)
    - Added instance template for home page
    See [eb7d20a](https://github.com/QutBioacoustics/baw-server/commit/eb7d20a02ac42bc6957eaddd61d646ed65e0350b)
    - General cleanup of view code
    See [7af8cad](https://github.com/QutBioacoustics/baw-server/commit/7af8cadea71d0e45bc374c5161760ec253a6add7)
    - Adds owner user to project show and permissions pages
    See [e26a8e4](https://github.com/QutBioacoustics/baw-server/commit/e26a8e463ea607e00cdc46f018c6cf5329f34c66)

## [Release 1.2.2](https://github.com/QutBioacoustics/baw-server/releases/tag/1.2.2)

- 2017-02-24
    - Fixed bugs with site/project permissions - owners can once again create new sites. Further updated site new
    permissions to match specification.
    See [#328](https://github.com/QutBioacoustics/baw-server/issues/328)

## [Release 1.2.1](https://github.com/QutBioacoustics/baw-server/releases/tag/1.2.1)

 - 2017-02-20
   - Updated dependencies to fix production bug with harvesting
   See [921a82b](https://github.com/QutBioacoustics/baw-server/commit/921a82b359c1a51185b8384710cf95e557e47de6)

## [Release 1.2.0](https://github.com/QutBioacoustics/baw-server/releases/tag/1.2.0)

 - 2017-02-16
   - Added support for rendering markdown partials
   - Refactored existing instance partials and added a new instance partial for
   the credits page.

## [Release 1.1.0](https://github.com/QutBioacoustics/baw-server/releases/tag/1.1.0)

Our major new feature in this release is support for user based analysis-jobs!
 - 2017-02-01
   - Brand new design for our secondary navigation menu. Should be much easier
   for users to navidate through our menus now.
   See [#313](https://github.com/QutBioacoustics/baw-server/pull/313)
 - 2017-01-23
   - Fixed an important bug that prevented high quality audio data from being
   sent to users on the listen page. There were several bugs in the byte
   range request code.
   See [#319](https://github.com/QutBioacoustics/baw-server/pull/319)
 - 2017-01-06
   - Fix flash notifications. A notification consisting of _true_ no longer
   flashes up when a user comes back to the site with an expires session.
   See [#242](https://github.com/QutBioacoustics/baw-server/issues/242)
 - 2016-12-11
   - The REST API no longer returns every site (even those not in the project)
   when a site listing of an empty project is requested.
   See [#312](https://github.com/QutBioacoustics/baw-server/pull/312)
   - The annotation downloader no longer return deleted audio events
   See [#310](https://github.com/QutBioacoustics/baw-server/pull/310)
 - 2016-12-04
   - The REST API now better handles malformed payloads.
   See [#309](https://github.com/QutBioacoustics/baw-server/pull/309)
 - 2016-11-25
   - Further refinements to analysis jobs, See
       - [f9e2036](https://github.com/QutBioacoustics/baw-server/commit/f9e2036b7190279577a9469f37146e41f2f139e4)
       - [8b770bf](https://github.com/QutBioacoustics/baw-server/commit/8b770bfccbe9b09df9973e3a7955f6542195e0b1)
       - [5fd6970](https://github.com/QutBioacoustics/baw-server/commit/5fd6970b6418ca19f5381ef6aef25de7e39125ca)
 - 2016-10-20
   - Enhanced annotation download page to make the choices clearer for users
   See [#304](https://github.com/QutBioacoustics/baw-server/commit/114831322a8dd2b329f71e130b4f9afbfaf39582)
 - 2016-09-16
   - Added support for partial payloads for analysis jobs items
   See [5f96b96](https://github.com/QutBioacoustics/baw-server/commit/5f96b963480c3192533759f9fdf8fa2cfb08f1f0)
-
 - 2016-09-13
   - Updated gems [6e469cf](https://github.com/QutBioacoustics/baw-server/commit/6e469cf4be7e16ce632f5b380e7c9101fea36bdb)
 - 2016-08-10
   - Removing support for Ruby 2.2.3 [eac760c](https://github.com/QutBioacoustics/baw-server/commit/eac760c4351131a05fdcce6fdd2dce1e8d0a6568)
 - 2016-08-09
   - Fix: Split out analysis jobs items API from analysis results API.
    See [#301](https://github.com/QutBioacoustics/baw-server/issues/301)
 - 2016-08-03
   - Feature: Analysis Jobs items integration. Analysis jobs have been setup and their complete workflows tested and integrated. See [#300](https://github.com/QutBioacoustics/baw-server/pull/300)

## [Release 0.19.2](https://github.com/QutBioacoustics/baw-server/releases/tag/0.19.2) (2016-06-26)

 - 2016-06-21
   - Fixed critical auth bug for analysis results endpoint [#294](https://github.com/QutBioacoustics/baw-server/issues/294)
 - 2016-06-20
   - Bug fixes for processing and working with timezone fields. API now automatically fixes up ill-
     formatted timezone entries in the database. [52866cd](https://github.com/QutBioacoustics/baw-server/commit/52866cd371d3438c8c63e8d1b32a4af8796fd895)

## [Release 0.19.1](https://github.com/QutBioacoustics/baw-server/releases/tag/0.19.1) (2016-06-17)

 - 2016-06-11
   - Fixed outdated reference to baw-workers[ebeaab5](https://github.com/QutBioacoustics/baw-server/commit/ebeaab569f85bad22325c01628e47118ac7662f6)

## [Release 0.19.0](https://github.com/QutBioacoustics/baw-server/releases/tag/0.19.0) (2016-06-17)

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


\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
