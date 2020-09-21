Feature: Upload Service

  Background:
    Given the upload service is configured
    And an empty harvester_to_do directory

  Scenario: getting service status
    When we check service status
    Then it should be good

    When service not available
    And we check service status
    Then it should be bad

  Scenario: getting version infromation about the service
    When version info is fetched
    Then it contains the version

  Scenario: creating and deleting users
    Given the users:
      | name | password |
      | abcd | password |
      | efgh | password |
      | ijkl | password |
    When we query for users
    Then we should find those same users

    When we delete all users
    And we query for users
    Then we find 0 users

  Scenario: uploading a file
    Given there are no upload users
    When I create a user named harvest_123 with the password abc
    Then the user should expire in 7 days
    And I can upload the audio_file_mono file
    Then it should exist in the harvester directory, in the user directory
    Then I upload:
      | file                      | to             | expected       |
      | sqlite_fixture            | /              | ./             |
      | sqlite_fixture            | /              | ./             |
      | audio_file_amp_channels_1 | /nested/a/b/c/ | ./nested/a/b/c |
      | audio_file_wac_2          | /sub/a/./../   | ./sub          |
      | audio_file_wac_1          | /../../../     | ./             |
    Then I delete all the files

  Scenario: user ableness
    Given I create a user named harvest_456 with the password abc
    When I disable the user
    Then I can't upload the audio_file_mono file

    When I enable the user
    Then I can upload the audio_file_mono file
