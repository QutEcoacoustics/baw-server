# Changelog

## [12.18.5](https://github.com/QutEcoacoustics/baw-server/tree/12.18.5) (2025-06-24)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.18.1...12.18.5)

**Fixed bugs:**

- retry application job on PG::ConnectionBad [\#783](https://github.com/QutEcoacoustics/baw-server/issues/783)
- Curl retry attempts are too frequent [\#782](https://github.com/QutEcoacoustics/baw-server/issues/782)
- Friendly name can be nil when site\_id is nil. What to do for analysis jobs? [\#781](https://github.com/QutEcoacoustics/baw-server/issues/781)

## [12.18.1](https://github.com/QutEcoacoustics/baw-server/tree/12.18.1) (2025-06-20)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.18.0...12.18.1)

## [12.18.0](https://github.com/QutEcoacoustics/baw-server/tree/12.18.0) (2025-06-19)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.17.6...12.18.0)

**Fixed bugs:**

- Curl request for status update does not run more than once for a 502 error [\#766](https://github.com/QutEcoacoustics/baw-server/issues/766)

## [12.17.6](https://github.com/QutEcoacoustics/baw-server/tree/12.17.6) (2025-06-18)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.16.1...12.17.6)

**Implemented enhancements:**

- Add associations for audio event imports and verifications to audio events endpoint [\#768](https://github.com/QutEcoacoustics/baw-server/issues/768)
- \# Improve database conflict error messages [\#767](https://github.com/QutEcoacoustics/baw-server/pull/767) ([andrew-1234](https://github.com/andrew-1234))

**Fixed bugs:**

- Need to gracefully handle disconnects to the pbs scheduler [\#776](https://github.com/QutEcoacoustics/baw-server/issues/776)
- Tag transformer should trim leading/trailing spaces in array items [\#774](https://github.com/QutEcoacoustics/baw-server/issues/774)
- Need to handle case where qdel is happening for exiting job: [\#765](https://github.com/QutEcoacoustics/baw-server/issues/765)
- Dynamic maximum enqueue threshold not `min`ed [\#764](https://github.com/QutEcoacoustics/baw-server/issues/764)
- If a site is deleted, and there are mappings in a harvest, the harvest is no longer valid and cannot be used [\#673](https://github.com/QutEcoacoustics/baw-server/issues/673)
- Remove invalid sites from Harvest mappings [\#772](https://github.com/QutEcoacoustics/baw-server/pull/772) ([andrew-1234](https://github.com/andrew-1234))

**Closed issues:**

- retry application job on ActiveRecord::DatabaseConnectionError [\#777](https://github.com/QutEcoacoustics/baw-server/issues/777)

**Merged pull requests:**

- Audio event associations [\#773](https://github.com/QutEcoacoustics/baw-server/pull/773) ([andrew-1234](https://github.com/andrew-1234))

## [12.16.1](https://github.com/QutEcoacoustics/baw-server/tree/12.16.1) (2025-05-30)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.16.0...12.16.1)

## [12.16.0](https://github.com/QutEcoacoustics/baw-server/tree/12.16.0) (2025-05-29)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.14.2...12.16.0)

**Implemented enhancements:**

- Expose `score` through `audio_event` model [\#762](https://github.com/QutEcoacoustics/baw-server/issues/762)
- Dynamic setting: batch\_analysis.remote\_enqueue\_limit [\#760](https://github.com/QutEcoacoustics/baw-server/issues/760)
- Dynamic settings module [\#759](https://github.com/QutEcoacoustics/baw-server/issues/759)
- Emit score field from audio event responses [\#763](https://github.com/QutEcoacoustics/baw-server/pull/763) ([hudson-newey](https://github.com/hudson-newey))
- Add site settings management with dynamic configuration [\#761](https://github.com/QutEcoacoustics/baw-server/pull/761) ([atruskie](https://github.com/atruskie))

**Closed issues:**

- We may need a custom REST endpoint / API for importing annotation results as annotations [\#197](https://github.com/QutEcoacoustics/baw-server/issues/197)

## [12.14.2](https://github.com/QutEcoacoustics/baw-server/tree/12.14.2) (2025-04-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.14.1...12.14.2)

**Implemented enhancements:**

- Allow filtering by region id for audio event download endpoint [\#740](https://github.com/QutEcoacoustics/baw-server/issues/740)
- Add verification data to annotation download CSV [\#739](https://github.com/QutEcoacoustics/baw-server/issues/739)
- Update audio event csv download [\#748](https://github.com/QutEcoacoustics/baw-server/pull/748) ([andrew-1234](https://github.com/andrew-1234))

**Fixed bugs:**

- Analysis jobs never set started\_at [\#751](https://github.com/QutEcoacoustics/baw-server/issues/751)
- analysis jobs item used\_memory\_bytes should be a bigint [\#712](https://github.com/QutEcoacoustics/baw-server/issues/712)

## [12.14.1](https://github.com/QutEcoacoustics/baw-server/tree/12.14.1) (2025-04-02)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.13.1...12.14.1)

**Fixed bugs:**

- Ensure aborted recordings are filtered out of common scenarios [\#736](https://github.com/QutEcoacoustics/baw-server/issues/736)

**Merged pull requests:**

- Filters out not-ready recordings from audio recording endpoints [\#749](https://github.com/QutEcoacoustics/baw-server/pull/749) ([atruskie](https://github.com/atruskie))

## [12.13.1](https://github.com/QutEcoacoustics/baw-server/tree/12.13.1) (2025-03-21)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.12.3...12.13.1)

**Implemented enhancements:**

- Adds support for importing avianz annotations [\#735](https://github.com/QutEcoacoustics/baw-server/pull/735) ([atruskie](https://github.com/atruskie))

## [12.12.3](https://github.com/QutEcoacoustics/baw-server/tree/12.12.3) (2025-03-19)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.12.1...12.12.3)

## [12.12.1](https://github.com/QutEcoacoustics/baw-server/tree/12.12.1) (2025-03-19)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.10.6...12.12.1)

**Fixed bugs:**

- Crash while parsing pbs status in analysis jobs [\#729](https://github.com/QutEcoacoustics/baw-server/issues/729)
- Makes auth token expire only if not used after a while [\#730](https://github.com/QutEcoacoustics/baw-server/pull/730) ([atruskie](https://github.com/atruskie))

**Closed issues:**

- Upsert api route for current user verifications [\#724](https://github.com/QutEcoacoustics/baw-server/issues/724)

**Merged pull requests:**

- Verification upsert api route [\#726](https://github.com/QutEcoacoustics/baw-server/pull/726) ([andrew-1234](https://github.com/andrew-1234))

## [12.10.6](https://github.com/QutEcoacoustics/baw-server/tree/12.10.6) (2025-03-06)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.10.5...12.10.6)

**Implemented enhancements:**

- 409 Conflict errors should respond with what model \(id\) it conflicts with [\#722](https://github.com/QutEcoacoustics/baw-server/issues/722)

## [12.10.5](https://github.com/QutEcoacoustics/baw-server/tree/12.10.5) (2025-03-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.10.4...12.10.5)

## [12.10.4](https://github.com/QutEcoacoustics/baw-server/tree/12.10.4) (2025-03-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.10.3...12.10.4)

## [12.10.3](https://github.com/QutEcoacoustics/baw-server/tree/12.10.3) (2025-03-02)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.10.1...12.10.3)

## [12.10.1](https://github.com/QutEcoacoustics/baw-server/tree/12.10.1) (2025-02-28)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.9.3...12.10.1)

**Implemented enhancements:**

- audio\_event `channel` property should be writable [\#717](https://github.com/QutEcoacoustics/baw-server/issues/717)
- Adds channel to audio event permitted params [\#720](https://github.com/QutEcoacoustics/baw-server/pull/720) ([andrew-1234](https://github.com/andrew-1234))

**Closed issues:**

- New provenance model & route [\#651](https://github.com/QutEcoacoustics/baw-server/issues/651)

## [12.9.3](https://github.com/QutEcoacoustics/baw-server/tree/12.9.3) (2025-02-25)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.9.1...12.9.3)

## [12.9.1](https://github.com/QutEcoacoustics/baw-server/tree/12.9.1) (2025-02-21)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.8.4...12.9.1)

**Implemented enhancements:**

- Adds unique constraint to path on harvest\_items [\#718](https://github.com/QutEcoacoustics/baw-server/pull/718) ([andrew-1234](https://github.com/andrew-1234))

## [12.8.4](https://github.com/QutEcoacoustics/baw-server/tree/12.8.4) (2025-02-19)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.13...12.8.4)

**Implemented enhancements:**

- Add a unique constraint to `path` on `harvest_items` [\#660](https://github.com/QutEcoacoustics/baw-server/issues/660)
- Adds a Verification API [\#713](https://github.com/QutEcoacoustics/baw-server/pull/713) ([andrew-1234](https://github.com/andrew-1234))

**Fixed bugs:**

- Importing multiple additional tags only imports the first tag [\#716](https://github.com/QutEcoacoustics/baw-server/issues/716)
- Parsing audio event CSV incorrectly recognizes date/time as recording ID [\#715](https://github.com/QutEcoacoustics/baw-server/issues/715)

**Closed issues:**

- Changes to annotation upload api [\#664](https://github.com/QutEcoacoustics/baw-server/issues/664)

## [12.6.13](https://github.com/QutEcoacoustics/baw-server/tree/12.6.13) (2025-02-05)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.12...12.6.13)

## [12.6.12](https://github.com/QutEcoacoustics/baw-server/tree/12.6.12) (2025-02-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.11...12.6.12)

## [12.6.11](https://github.com/QutEcoacoustics/baw-server/tree/12.6.11) (2025-01-30)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.6...12.6.11)

## [12.6.6](https://github.com/QutEcoacoustics/baw-server/tree/12.6.6) (2025-01-28)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.5...12.6.6)

## [12.6.5](https://github.com/QutEcoacoustics/baw-server/tree/12.6.5) (2025-01-28)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.4...12.6.5)

## [12.6.4](https://github.com/QutEcoacoustics/baw-server/tree/12.6.4) (2025-01-24)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.3...12.6.4)

## [12.6.3](https://github.com/QutEcoacoustics/baw-server/tree/12.6.3) (2025-01-24)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.2...12.6.3)

## [12.6.2](https://github.com/QutEcoacoustics/baw-server/tree/12.6.2) (2025-01-22)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.1...12.6.2)

## [12.6.1](https://github.com/QutEcoacoustics/baw-server/tree/12.6.1) (2025-01-22)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.6.0...12.6.1)

## [12.6.0](https://github.com/QutEcoacoustics/baw-server/tree/12.6.0) (2025-01-21)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.4.1...12.6.0)

**Implemented enhancements:**

- Verification API endpoint [\#705](https://github.com/QutEcoacoustics/baw-server/issues/705)

## [12.4.1](https://github.com/QutEcoacoustics/baw-server/tree/12.4.1) (2025-01-21)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.4.0...12.4.1)

## [12.4.0](https://github.com/QutEcoacoustics/baw-server/tree/12.4.0) (2025-01-20)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.1.2...12.4.0)

**Implemented enhancements:**

- Add an Opt-in For Communications [\#692](https://github.com/QutEcoacoustics/baw-server/issues/692)

**Fixed bugs:**

- Error: incompatible character encodings: UTF-8 and ASCII-8BIT  [\#702](https://github.com/QutEcoacoustics/baw-server/issues/702)
- Fix stale job scheduling [\#701](https://github.com/QutEcoacoustics/baw-server/pull/701) ([atruskie](https://github.com/atruskie))

**Merged pull requests:**

- Make harvester more resilient to bad paths [\#704](https://github.com/QutEcoacoustics/baw-server/pull/704) ([atruskie](https://github.com/atruskie))
- Dev improvements [\#700](https://github.com/QutEcoacoustics/baw-server/pull/700) ([atruskie](https://github.com/atruskie))
- macos dev compatability [\#699](https://github.com/QutEcoacoustics/baw-server/pull/699) ([andrew-1234](https://github.com/andrew-1234))

## [12.1.2](https://github.com/QutEcoacoustics/baw-server/tree/12.1.2) (2024-12-20)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.1.1...12.1.2)

## [12.1.1](https://github.com/QutEcoacoustics/baw-server/tree/12.1.1) (2024-12-20)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.1.0...12.1.1)

## [12.1.0](https://github.com/QutEcoacoustics/baw-server/tree/12.1.0) (2024-12-19)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.0.3...12.1.0)

## [12.0.3](https://github.com/QutEcoacoustics/baw-server/tree/12.0.3) (2024-12-17)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.0.2...12.0.3)

## [12.0.2](https://github.com/QutEcoacoustics/baw-server/tree/12.0.2) (2024-12-17)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.0.1...12.0.2)

## [12.0.1](https://github.com/QutEcoacoustics/baw-server/tree/12.0.1) (2024-12-17)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/12.0.0...12.0.1)

## [12.0.0](https://github.com/QutEcoacoustics/baw-server/tree/12.0.0) (2024-12-09)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/10.0.1...12.0.0)

**Merged pull requests:**

- Redesigned the analysis jobs system [\#696](https://github.com/QutEcoacoustics/baw-server/pull/696) ([atruskie](https://github.com/atruskie))

## [10.0.1](https://github.com/QutEcoacoustics/baw-server/tree/10.0.1) (2024-08-09)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/9.2.2...10.0.1)

**Implemented enhancements:**

- Add nullable license field to Projects model [\#669](https://github.com/QutEcoacoustics/baw-server/pull/669) ([hudson-newey](https://github.com/hudson-newey))

**Fixed bugs:**

- Incorrect association assignment for nested site routes [\#679](https://github.com/QutEcoacoustics/baw-server/issues/679)

**Closed issues:**

- Encode license and attribution information in project models [\#289](https://github.com/QutEcoacoustics/baw-server/issues/289)

**Merged pull requests:**

- Fixes multiple assignment bug [\#680](https://github.com/QutEcoacoustics/baw-server/pull/680) ([atruskie](https://github.com/atruskie))

## [9.2.2](https://github.com/QutEcoacoustics/baw-server/tree/9.2.2) (2023-09-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/9.1.1...9.2.2)

**Implemented enhancements:**

- change statistics tables to logged [\#635](https://github.com/QutEcoacoustics/baw-server/issues/635)

**Fixed bugs:**

- Problem parsing EMU results [\#631](https://github.com/QutEcoacoustics/baw-server/issues/631)

## [9.1.1](https://github.com/QutEcoacoustics/baw-server/tree/9.1.1) (2022-12-05)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/9.0.3...9.1.1)

**Fixed bugs:**

- aborting a harvest in the new\_harvest state throws an exception [\#625](https://github.com/QutEcoacoustics/baw-server/issues/625)
- Login tokens not expiring after 24 hours [\#426](https://github.com/QutEcoacoustics/baw-server/issues/426)

**Closed issues:**

- Add JWT authentication [\#632](https://github.com/QutEcoacoustics/baw-server/issues/632)
- Missing official login route [\#509](https://github.com/QutEcoacoustics/baw-server/issues/509)
- Login route missing user id [\#433](https://github.com/QutEcoacoustics/baw-server/issues/433)

## [9.0.3](https://github.com/QutEcoacoustics/baw-server/tree/9.0.3) (2022-10-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/9.0.2...9.0.3)

**Implemented enhancements:**

- Support processing partial data files [\#624](https://github.com/QutEcoacoustics/baw-server/issues/624)

**Closed issues:**

- Add an optional name field to harvest [\#619](https://github.com/QutEcoacoustics/baw-server/issues/619)

## [9.0.2](https://github.com/QutEcoacoustics/baw-server/tree/9.0.2) (2022-09-14)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/9.0.1...9.0.2)

**Fixed bugs:**

- EMU exit code check fail [\#623](https://github.com/QutEcoacoustics/baw-server/issues/623)

## [9.0.1](https://github.com/QutEcoacoustics/baw-server/tree/9.0.1) (2022-09-14)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/9.0.0...9.0.1)

## [9.0.0](https://github.com/QutEcoacoustics/baw-server/tree/9.0.0) (2022-09-09)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.16.0...9.0.0)

**Fixed bugs:**

- A NoMethodError occurred in sites\#filter: [\#621](https://github.com/QutEcoacoustics/baw-server/issues/621)

## [8.16.0](https://github.com/QutEcoacoustics/baw-server/tree/8.16.0) (2022-08-24)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.14.0...8.16.0)

**Fixed bugs:**

- Site: public jitter amount out by as much as 2km [\#620](https://github.com/QutEcoacoustics/baw-server/issues/620)

**Closed issues:**

- Harvest: unknown error processing files [\#617](https://github.com/QutEcoacoustics/baw-server/issues/617)

## [8.14.0](https://github.com/QutEcoacoustics/baw-server/tree/8.14.0) (2022-08-09)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.13.0...8.14.0)

## [8.13.0](https://github.com/QutEcoacoustics/baw-server/tree/8.13.0) (2022-08-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.12.4...8.13.0)

**Implemented enhancements:**

- Permissions: add user association to allow filtering permissions by username [\#616](https://github.com/QutEcoacoustics/baw-server/issues/616)

## [8.12.4](https://github.com/QutEcoacoustics/baw-server/tree/8.12.4) (2022-08-05)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.12.1...8.12.4)

**Fixed bugs:**

- Harvest: An AASM::InvalidTransition occurred in background  [\#615](https://github.com/QutEcoacoustics/baw-server/issues/615)
- Harvest: timeout while processing HarvestItem should schedule a retry [\#614](https://github.com/QutEcoacoustics/baw-server/issues/614)
- Harvest: transitioning to scan state in production sometimes does not save state [\#613](https://github.com/QutEcoacoustics/baw-server/issues/613)

## [8.12.1](https://github.com/QutEcoacoustics/baw-server/tree/8.12.1) (2022-08-02)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.11.3...8.12.1)

**Implemented enhancements:**

- Site safe name function: check stack delimiters are squashed [\#611](https://github.com/QutEcoacoustics/baw-server/issues/611)
- Harvest Job validations: check validation messages do not mention harvest items [\#610](https://github.com/QutEcoacoustics/baw-server/issues/610)
- Harvest: wrong validation message shown FL001 [\#609](https://github.com/QutEcoacoustics/baw-server/issues/609)

## [8.11.3](https://github.com/QutEcoacoustics/baw-server/tree/8.11.3) (2022-07-29)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.7.0...8.11.3)

**Implemented enhancements:**

- Harvest: transition from metadata\_review to metadata\_extraction or process is a very large request [\#603](https://github.com/QutEcoacoustics/baw-server/issues/603)
- Ensure harvest works with various Frontier Labs problems [\#597](https://github.com/QutEcoacoustics/baw-server/issues/597)

**Fixed bugs:**

- Harvests: harvest overlapping validations appears to be matching files from other harvests [\#605](https://github.com/QutEcoacoustics/baw-server/issues/605)
- Harvest: authentication to sftpgo is failing when token is expired [\#602](https://github.com/QutEcoacoustics/baw-server/issues/602)
- Harvest: find\_mapping\_for\_path could match the incorrect mapping [\#601](https://github.com/QutEcoacoustics/baw-server/issues/601)

**Closed issues:**

- Harvest: show action - renewing upload user expiry failure should not prevent successful response [\#606](https://github.com/QutEcoacoustics/baw-server/issues/606)

## [8.7.0](https://github.com/QutEcoacoustics/baw-server/tree/8.7.0) (2022-07-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.6.0...8.7.0)

**Implemented enhancements:**

- Auto-renew sftpgo user when expiry date is near [\#600](https://github.com/QutEcoacoustics/baw-server/issues/600)

**Fixed bugs:**

- An ActiveRecord::ConnectionNotEstablished occurred in media\#show: [\#575](https://github.com/QutEcoacoustics/baw-server/issues/575)

## [8.6.0](https://github.com/QutEcoacoustics/baw-server/tree/8.6.0) (2022-06-30)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.5.11...8.6.0)

**Implemented enhancements:**

- Allow CSV format results for endpoints [\#598](https://github.com/QutEcoacoustics/baw-server/issues/598)

## [8.5.11](https://github.com/QutEcoacoustics/baw-server/tree/8.5.11) (2022-06-30)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.5.10...8.5.11)

## [8.5.10](https://github.com/QutEcoacoustics/baw-server/tree/8.5.10) (2022-06-30)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.2.0...8.5.10)

**Implemented enhancements:**

- Add scan job for streaming uploads [\#588](https://github.com/QutEcoacoustics/baw-server/issues/588)
- Avoid setting user stamps when updater is nil [\#587](https://github.com/QutEcoacoustics/baw-server/issues/587)
- Add special case for sites with the same name for default harvest folder creation [\#586](https://github.com/QutEcoacoustics/baw-server/issues/586)
- Harvester fixes [\#599](https://github.com/QutEcoacoustics/baw-server/pull/599) ([atruskie](https://github.com/atruskie))

**Fixed bugs:**

- Harvest Items directory listing is returning incorrect results [\#595](https://github.com/QutEcoacoustics/baw-server/issues/595)
- Harvest: ignore .filepart files [\#594](https://github.com/QutEcoacoustics/baw-server/issues/594)
- Harvest: substituting and incorrect project id in the route does not throw an error [\#593](https://github.com/QutEcoacoustics/baw-server/issues/593)
- Harvest:  undefined local variable or method `extension` [\#592](https://github.com/QutEcoacoustics/baw-server/issues/592)
- Handle service unavailability. [\#591](https://github.com/QutEcoacoustics/baw-server/issues/591)
- Harvest: some harvest items remain stuck on new [\#590](https://github.com/QutEcoacoustics/baw-server/issues/590)
- Harvests: account for errors in metadata stage [\#589](https://github.com/QutEcoacoustics/baw-server/issues/589)

## [8.2.0](https://github.com/QutEcoacoustics/baw-server/tree/8.2.0) (2022-06-15)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.1.0...8.2.0)

**Fixed bugs:**

- Upload host split [\#585](https://github.com/QutEcoacoustics/baw-server/pull/585) ([atruskie](https://github.com/atruskie))

**Closed issues:**

- Allow user to upload annotations [\#573](https://github.com/QutEcoacoustics/baw-server/issues/573)

## [8.1.0](https://github.com/QutEcoacoustics/baw-server/tree/8.1.0) (2022-06-06)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/8.0.0...8.1.0)

**Implemented enhancements:**

- Harvest model updates [\#583](https://github.com/QutEcoacoustics/baw-server/issues/583)

**Closed issues:**

- Missing capability details [\#419](https://github.com/QutEcoacoustics/baw-server/issues/419)

**Merged pull requests:**

- Harvest model updates [\#584](https://github.com/QutEcoacoustics/baw-server/pull/584) ([atruskie](https://github.com/atruskie))

## [8.0.0](https://github.com/QutEcoacoustics/baw-server/tree/8.0.0) (2022-05-27)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.4.0...8.0.0)

**Closed issues:**

- Create a remote upload interface [\#539](https://github.com/QutEcoacoustics/baw-server/issues/539)

**Merged pull requests:**

- Adds Harvest table and APIs [\#582](https://github.com/QutEcoacoustics/baw-server/pull/582) ([atruskie](https://github.com/atruskie))

## [7.4.0](https://github.com/QutEcoacoustics/baw-server/tree/7.4.0) (2022-04-07)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.3.1...7.4.0)

**Fixed bugs:**

- Login with downloader script bugged when using username and password [\#570](https://github.com/QutEcoacoustics/baw-server/issues/570)

## [7.3.1](https://github.com/QutEcoacoustics/baw-server/tree/7.3.1) (2022-04-06)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.3.0...7.3.1)

**Implemented enhancements:**

- Harvest instructions are out of date [\#317](https://github.com/QutEcoacoustics/baw-server/issues/317)

**Fixed bugs:**

- Bad tzinfo\_tz values in production databases [\#569](https://github.com/QutEcoacoustics/baw-server/issues/569)

## [7.3.0](https://github.com/QutEcoacoustics/baw-server/tree/7.3.0) (2022-04-04)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.2.1...7.3.0)

**Implemented enhancements:**

- API: filter setting are not applied to single object response [\#565](https://github.com/QutEcoacoustics/baw-server/issues/565)

**Fixed bugs:**

- An ActiveRecord::StatementInvalid occurred in media\#show: [\#534](https://github.com/QutEcoacoustics/baw-server/issues/534)
- Fixes deadlocks and constraint violation in statistics trackers [\#568](https://github.com/QutEcoacoustics/baw-server/pull/568) ([atruskie](https://github.com/atruskie))

## [7.2.1](https://github.com/QutEcoacoustics/baw-server/tree/7.2.1) (2022-03-29)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.1.0...7.2.1)

**Implemented enhancements:**

- Support arrays for filter conditions in combiner nodes [\#567](https://github.com/QutEcoacoustics/baw-server/issues/567)

**Fixed bugs:**

- Ambiguous column reference for tzinfo\_tz in expressions query [\#566](https://github.com/QutEcoacoustics/baw-server/issues/566)

## [7.1.0](https://github.com/QutEcoacoustics/baw-server/tree/7.1.0) (2022-03-24)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.0.1...7.1.0)

**Implemented enhancements:**

- Filter recordings by time of day [\#562](https://github.com/QutEcoacoustics/baw-server/issues/562)

**Merged pull requests:**

- Time of day feature [\#563](https://github.com/QutEcoacoustics/baw-server/pull/563) ([atruskie](https://github.com/atruskie))

## [7.0.1](https://github.com/QutEcoacoustics/baw-server/tree/7.0.1) (2022-03-09)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/7.0.0...7.0.1)

## [7.0.0](https://github.com/QutEcoacoustics/baw-server/tree/7.0.0) (2022-03-09)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/6.1.1...7.0.0)

**Implemented enhancements:**

- Permissions endpoint [\#559](https://github.com/QutEcoacoustics/baw-server/pull/559) ([yupengKenny](https://github.com/yupengKenny))

**Closed issues:**

- Missing project individual user permissions route [\#432](https://github.com/QutEcoacoustics/baw-server/issues/432)

## [6.1.1](https://github.com/QutEcoacoustics/baw-server/tree/6.1.1) (2022-02-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/6.1.0...6.1.1)

## [6.1.0](https://github.com/QutEcoacoustics/baw-server/tree/6.1.0) (2022-02-08)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/5.1.0...6.1.0)

**Implemented enhancements:**

- add `filter` QSP to API requests that accepts a base64 encoded filter payload [\#555](https://github.com/QutEcoacoustics/baw-server/issues/555)
- Adds support for encoded filters for API use [\#556](https://github.com/QutEcoacoustics/baw-server/pull/556) ([atruskie](https://github.com/atruskie))

## [5.1.0](https://github.com/QutEcoacoustics/baw-server/tree/5.1.0) (2022-01-17)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/5.0.0...5.1.0)

**Fixed bugs:**

- Unhandled error in AudioRecording model API response [\#553](https://github.com/QutEcoacoustics/baw-server/issues/553)
- Fixes Current.ability [\#554](https://github.com/QutEcoacoustics/baw-server/pull/554) ([atruskie](https://github.com/atruskie))

## [5.0.0](https://github.com/QutEcoacoustics/baw-server/tree/5.0.0) (2021-12-14)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.9.1...5.0.0)

**Implemented enhancements:**

- Original download capability [\#551](https://github.com/QutEcoacoustics/baw-server/issues/551)
- Adds original download capability [\#552](https://github.com/QutEcoacoustics/baw-server/pull/552) ([atruskie](https://github.com/atruskie))

## [4.9.1](https://github.com/QutEcoacoustics/baw-server/tree/4.9.1) (2021-12-10)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.9.0...4.9.1)

**Fixed bugs:**

- Filter queries are failing when projections are camelCased [\#550](https://github.com/QutEcoacoustics/baw-server/issues/550)

## [4.9.0](https://github.com/QutEcoacoustics/baw-server/tree/4.9.0) (2021-12-05)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.8.7...4.9.0)

**Implemented enhancements:**

- Allow include/exclude of custom\_fields \(Expose site location in filter projection\) [\#495](https://github.com/QutEcoacoustics/baw-server/issues/495)

## [4.8.7](https://github.com/QutEcoacoustics/baw-server/tree/4.8.7) (2021-11-19)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.8.0...4.8.7)

## [4.8.0](https://github.com/QutEcoacoustics/baw-server/tree/4.8.0) (2021-11-10)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.7.1.0...4.8.0)

**Implemented enhancements:**

- Expose original audio download route to the public [\#538](https://github.com/QutEcoacoustics/baw-server/issues/538)
- Expose original audio download route [\#548](https://github.com/QutEcoacoustics/baw-server/pull/548) ([atruskie](https://github.com/atruskie))

**Fixed bugs:**

- Use consistency\_fail gem to add db indexes for uniqueness constraints [\#138](https://github.com/QutEcoacoustics/baw-server/issues/138)

**Closed issues:**

- UI updates from design feedback [\#326](https://github.com/QutEcoacoustics/baw-server/issues/326)

## [4.7.1.0](https://github.com/QutEcoacoustics/baw-server/tree/4.7.1.0) (2021-09-28)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.7...4.7.1.0)

## [4.7](https://github.com/QutEcoacoustics/baw-server/tree/4.7) (2021-09-28)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.6.3...4.7)

## [4.6.3](https://github.com/QutEcoacoustics/baw-server/tree/4.6.3) (2021-08-31)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.6.2...4.6.3)

## [4.6.2](https://github.com/QutEcoacoustics/baw-server/tree/4.6.2) (2021-08-31)

[Full Changelog](https://github.com/QutEcoacoustics/baw-server/compare/4.6.1...4.6.2)

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
