# frozen_string_literal: true

require_relative 'verification_states_helper'

describe 'Filtering AudioEvents by Verification states:' do
  # The test data is a truth table with one row per audio event, so it is easy to look up which events match a set of
  # conditions. For example, find `C` in the u1:t1 column to see the events I verified as correct for t1.
  #
  #   event   the name of the audio event. Each name is also a helper that returns the event (a1, a2, ...).
  #   t1 t2   a tag the audio event has, marked with an x. t1 and t2 are the campaign tags.
  #   t3      a tag the audio event has that is outside the campaign.
  #   u1:t1   the verification user u1 made for tag t1 on the event: C correct, I incorrect, U unsure or S skip.
  #           u1 is me and u2 is another user. A blank cell means no verification.
  #
  # A verification does not need a matching tag on the event. Lines starting with # are skipped.
  # Keep columns aligned to the header widths. Double vertical bars mark the user-group boundaries.
  def self.truth_table = <<~TABLE
    | event | t1 | t2 | t3 ‖ u1:t1 | u1:t2 | u1:t3 ‖ u2:t1 | u2:t2 | u2:t3 ‖
    # The original scaffold: every combination of tags, with a few verifications.
    | a1    | x  | x  |    ‖ C     | C     |       ‖       |       | C     ‖
    | a2    | x  | x  |    ‖ I     |       |       ‖       | I     |       ‖
    | a3    | x  | x  |    ‖ U     |       |       ‖       | C     |       ‖
    | a4    | x  |    |    ‖ S     |       |       ‖       | C     |       ‖
    | a5    |    |    |    ‖       |       |       ‖       |       |       ‖
    | a6    |    | x  |    ‖       |       |       ‖       |       |       ‖
    | a7    | x  | x  | x  ‖       |       |       ‖       |       |       ‖
    | a8    |    |    | x  ‖       |       |       ‖       |       |       ‖
    | a9    | x  |    | x  ‖       |       |       ‖       |       |       ‖
    | a10   |    | x  | x  ‖       |       |       ‖       |       |       ‖
    # Tag t1 only: every variant for u1 against every variant for u2.
    | a11   | x  |    |    ‖       |       |       ‖       |       |       ‖
    | a12   | x  |    |    ‖       |       |       ‖ C     |       |       ‖
    | a13   | x  |    |    ‖       |       |       ‖ I     |       |       ‖
    | a14   | x  |    |    ‖       |       |       ‖ U     |       |       ‖
    | a15   | x  |    |    ‖       |       |       ‖ S     |       |       ‖
    | a16   | x  |    |    ‖ C     |       |       ‖       |       |       ‖
    | a17   | x  |    |    ‖ C     |       |       ‖ C     |       |       ‖
    | a18   | x  |    |    ‖ C     |       |       ‖ I     |       |       ‖
    | a19   | x  |    |    ‖ C     |       |       ‖ U     |       |       ‖
    | a20   | x  |    |    ‖ C     |       |       ‖ S     |       |       ‖
    | a21   | x  |    |    ‖ I     |       |       ‖       |       |       ‖
    | a22   | x  |    |    ‖ I     |       |       ‖ C     |       |       ‖
    | a23   | x  |    |    ‖ I     |       |       ‖ I     |       |       ‖
    | a24   | x  |    |    ‖ I     |       |       ‖ U     |       |       ‖
    | a25   | x  |    |    ‖ I     |       |       ‖ S     |       |       ‖
    | a26   | x  |    |    ‖ U     |       |       ‖       |       |       ‖
    | a27   | x  |    |    ‖ U     |       |       ‖ C     |       |       ‖
    | a28   | x  |    |    ‖ U     |       |       ‖ I     |       |       ‖
    | a29   | x  |    |    ‖ U     |       |       ‖ U     |       |       ‖
    | a30   | x  |    |    ‖ U     |       |       ‖ S     |       |       ‖
    | a31   | x  |    |    ‖ S     |       |       ‖       |       |       ‖
    | a32   | x  |    |    ‖ S     |       |       ‖ C     |       |       ‖
    | a33   | x  |    |    ‖ S     |       |       ‖ I     |       |       ‖
    | a34   | x  |    |    ‖ S     |       |       ‖ U     |       |       ‖
    | a35   | x  |    |    ‖ S     |       |       ‖ S     |       |       ‖
    # Tag t2 only: one user at a time, then both users disagreeing.
    | a36   |    | x  |    ‖       | C     |       ‖       |       |       ‖
    | a37   |    | x  |    ‖       | I     |       ‖       |       |       ‖
    | a38   |    | x  |    ‖       | U     |       ‖       |       |       ‖
    | a39   |    | x  |    ‖       | S     |       ‖       |       |       ‖
    | a40   |    | x  |    ‖       |       |       ‖       | C     |       ‖
    | a41   |    | x  |    ‖       |       |       ‖       | I     |       ‖
    | a42   |    | x  |    ‖       |       |       ‖       | U     |       ‖
    | a43   |    | x  |    ‖       |       |       ‖       | S     |       ‖
    | a44   |    | x  |    ‖       | C     |       ‖       | I     |       ‖
    | a45   |    | x  |    ‖       | I     |       ‖       | C     |       ‖
    # Only verified for t3, the tag outside the campaign.
    | a46   | x  | x  | x  ‖       |       | C     ‖       |       |       ‖
    | a47   | x  | x  | x  ‖       |       | I     ‖       |       |       ‖
    | a48   | x  | x  | x  ‖       |       | U     ‖       |       |       ‖
    | a49   | x  | x  | x  ‖       |       | S     ‖       |       |       ‖
    | a50   | x  | x  | x  ‖       |       |       ‖       |       | C     ‖
    | a51   | x  | x  | x  ‖       |       |       ‖       |       | I     ‖
    | a52   | x  | x  | x  ‖       |       |       ‖       |       | U     ‖
    | a53   | x  | x  | x  ‖       |       |       ‖       |       | S     ‖
    # One user verifies t3 (outside the campaign), the other verifies t1 or t2 (inside it).
    | a54   | x  |    | x  ‖       |       | C     ‖ I     |       |       ‖
    | a55   | x  |    | x  ‖       |       | I     ‖ U     |       |       ‖
    | a56   | x  |    | x  ‖       |       | U     ‖ S     |       |       ‖
    | a57   | x  |    | x  ‖       |       | S     ‖ C     |       |       ‖
    | a58   |    | x  | x  ‖       | I     |       ‖       |       | C     ‖
    | a59   |    | x  | x  ‖       | U     |       ‖       |       | I     ‖
    | a60   |    | x  | x  ‖       | S     |       ‖       |       | U     ‖
    | a61   |    | x  | x  ‖       | C     |       ‖       |       | S     ‖
    # Both campaign tags on one event.
    | a62   | x  | x  |    ‖ S     | C     |       ‖       |       |       ‖
    | a63   | x  | x  |    ‖ C     | S     |       ‖       |       |       ‖
    | a64   | x  | x  |    ‖ S     | S     |       ‖       |       |       ‖
    | a65   | x  | x  |    ‖ C     | I     |       ‖       |       |       ‖
    | a66   | x  | x  |    ‖       | C     |       ‖       |       |       ‖
    | a67   | x  | x  |    ‖ C     |       |       ‖       | I     |       ‖
    | a68   | x  | x  |    ‖       |       |       ‖ S     | C     |       ‖
    # Verified for a campaign tag, but the event has no campaign tag.
    | a69   |    |    | x  ‖ C     |       |       ‖ I     |       |       ‖
    | a70   |    |    | x  ‖ I     |       |       ‖ U     |       |       ‖
    | a71   |    |    | x  ‖ U     |       |       ‖ S     |       |       ‖
    | a72   |    |    | x  ‖ S     |       |       ‖ C     |       |       ‖
  TABLE

  include_context 'with verification states'

  # ?
  # ? This file serves as documentation for devs that are trying to implement
  # ? filtering for audio events based on verification states. The spec titles
  # ! intentionally defines "verified" as `correct`, `incorrect`, or `unsure`
  # ? (so verifications that are skipped are not considered "verified")
  # ? because that's how we would use the term "verified" in our UI.
  # ?

  let(:me) { u1.id }

  context 'with any tag,' do
    context 'when finding events based on what I have verified' do
      it 'that I have not verified (or is labelled as skip)' do
        # We choose `none` here so that any other verification by the user would exclude the event from the results,
        # but empty sets still match.
        expect_matching_events(
          { verifications: { none: { creator_id: { eq: me }, confirmed: { not_eq: 'skip' } } } },
          4..10,
          11..15, 31..35,
          39..43,
          49..53,
          57, 60,
          64, 68,
          72
        )
      end

      it 'that I have verified (or not labelled as skip)' do
        # We choose `any`` here, because any matching verification sub-row, should return the audio event
        expect_matching_events(
          { verifications: { any: { creator_id: { eq: me }, confirmed: { not_eq: 'skip' } } } },
          1..3,
          16..30,
          36..38, 44..45,
          46..48,
          54..56, 58..59, 61,
          62..63, 65..67,
          69..71
        )
      end

      it 'that I have labeled as correct' do
        expect_matching_events(
          { verifications: { any: { creator_id: { eq: me }, confirmed: { eq: 'correct' } } } },
          1,
          16..20,
          36, 44,
          46,
          54, 61,
          62, 63, 65, 66, 67,
          69
        )
      end

      it 'that I have labeled as incorrect' do
        expect_matching_events(
          { verifications: { any: { creator_id: { eq: me }, confirmed: { eq: 'incorrect' } } } },
          2,
          21..25,
          37, 45,
          47,
          55, 58,
          65,
          70
        )
      end

      it 'that I have labeled as unsure' do
        expect_matching_events(
          { verifications: { any: { creator_id: { eq: me }, confirmed: { eq: 'unsure' } } } },
          3,
          26..30,
          38,
          48,
          56, 59,
          71
        )
      end

      it 'that I have labeled as skipped' do
        expect_matching_events(
          { verifications: { any: { creator_id: { eq: me }, confirmed: { eq: 'skip' } } } },
          4,
          31..35,
          39,
          49,
          57, 60,
          62..64,
          72
        )
      end

      it 'that I have been exposed to (any label including skip)' do
        expect_matching_events(
          { verifications: { any: { creator_id: { eq: me } } } },
          1..4,
          16..35,
          36..39, 44..45,
          46..49,
          54..61,
          62..67,
          69..72
        )
      end

      it 'that I have not been exposed to (no labels at all)' do
        expect_matching_events(
          { verifications: { none: { creator_id: { eq: me } } } },
          5..10,
          11..15,
          40..43,
          50..53,
          68
        )
      end
    end

    context 'when finding events based on what anyone has verified' do
      it 'that no one has verified (or is labelled as skip)' do
        expect_matching_events(
          { verifications: { none: { confirmed: { not_eq: 'skip' } } } },
          5..10,
          11,
          15, 31, 35,
          39, 43,
          49, 53,
          64
        )
      end

      it 'that anyone has verified (or not labelled as skip)' do
        expect_matching_events(
          { verifications: { any: { confirmed: { not_eq: 'skip' } } } },
          1..4,
          12..14, 16..30, 32..34,
          36..38, 40..42, 44..45,
          46..48, 50..52,
          54..61,
          62..63, 65..68,
          69..72
        )
      end

      it 'that anyone has labeled as correct' do
        expect_matching_events(
          { verifications: { any: { confirmed: { eq: 'correct' } } } },
          1, 3, 4,
          12, 16..20, 22, 27, 32,
          36, 40, 44, 45,
          46, 50,
          54, 57, 58, 61,
          62, 63, 65, 66, 67, 68,
          69, 72
        )
      end

      it 'that anyone has labeled as incorrect' do
        expect_matching_events(
          { verifications: { any: { confirmed: { eq: 'incorrect' } } } },
          2,
          13, 18, 21..25, 28, 33,
          37, 41, 44, 45,
          47, 51,
          54, 55, 58, 59,
          65, 67,
          69, 70
        )
      end

      it 'that anyone has labeled as unsure' do
        expect_matching_events(
          { verifications: { any: { confirmed: { eq: 'unsure' } } } },
          3,
          14, 19, 24, 26..30, 34,
          38, 42,
          48, 52,
          55..56, 59..60,
          70..71
        )
      end

      it 'that anyone has labeled as skipped' do
        expect_matching_events(
          { verifications: { any: { confirmed: { eq: 'skip' } } } },
          4,
          15, 20, 25, 30..35,
          39, 43,
          49, 53,
          56..57, 60..61,
          62..64, 68,
          71..72
        )
      end

      it 'that anyone has been exposed to (any label including skip)' do
        expect_matching_events(
          { verifications: { any: {} } },
          1..4,
          12..35,
          36..45,
          46..53,
          54..61,
          62..68,
          69..72
        )
      end

      it 'that no one has been exposed to (no labels at all)' do
        expect_matching_events(
          { verifications: { none: {} } },
          5..10,
          11
        )
      end
    end
  end

  context 'with a specific set of tags,' do
    # The target tags for this context are t1 and t2.
    # They are our "campaign".
    context 'when finding events based on what I have verified' do
      it 'that I have not verified (or is labelled as skip)' do
        # Work is left per tag: an event matches while any of its target tags has no verification from me.
        # The verifications scope is nested in the taggings scope, so it only sees the verifications
        # for the same event and tag as the tagging.
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                verifications: {
                  none: {
                    creator_id: { eq: me },
                    confirmed: { not_eq: 'skip' }
                  }
                }
              }
            }
          },
          2..4, 6..7, 9..10,
          11..15, 31..35,
          39..43,
          46..53,
          54..57, 60,
          62..64, 66..68
        )
      end

      # I kept this test in too because it's got a significantly different outcome without the taggings filter.
      it 'that I have not verified (or is labelled as skip) without a taggings filter' do
        expect_matching_events(
          {
            verifications: {
              none: {
                tag_id: { in: [t1.id, t2.id] },
                creator_id: { eq: me },
                confirmed: { not_eq: 'skip' }
              }
            }
          },
          4..10,
          11..15, 31..35,
          39..43,
          46..53,
          54..57, 60,
          64, 68,
          72
        )
      end

      it 'that I have verified (or not labelled as skip)' do
        expect_matching_events(
          {
            verifications: {
              any: { creator_id: { eq: me }, confirmed: { not_eq: 'skip' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          1..3,
          16..30,
          36..38, 44..45,
          58..59, 61,
          62..63, 65..67,
          69..71
        )
      end

      it 'that I have labeled as correct' do
        expect_matching_events(
          {
            verifications: {
              any: { creator_id: { eq: me }, confirmed: { eq: 'correct' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          1,
          16..20,
          36, 44,
          61,
          62..63, 65..67,
          69
        )
      end

      it 'that I have labeled as incorrect' do
        expect_matching_events(
          {
            verifications: {
              any: { creator_id: { eq: me }, confirmed: { eq: 'incorrect' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          2,
          21..25,
          37, 45,
          58,
          65,
          70
        )
      end

      it 'that I have labeled as unsure' do
        expect_matching_events(
          {
            verifications: {
              any: { creator_id: { eq: me }, confirmed: { eq: 'unsure' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          3,
          26..30,
          38,
          59,
          71
        )
      end

      it 'that I have labeled as skipped' do
        expect_matching_events(
          {
            verifications: {
              any: { creator_id: { eq: me }, confirmed: { eq: 'skip' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          4,
          31..35,
          39,
          60,
          62..64,
          72
        )
      end

      it 'that I have been exposed to (any label including skip)' do
        expect_matching_events(
          {
            verifications: {
              any: { creator_id: { eq: me }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          1..4,
          16..35,
          36..39, 44..45,
          58..61,
          62..67,
          69..72
        )
      end

      it 'that I have not been exposed to (no labels at all)' do
        # Work is left per tag: an event matches while any of its target tags has no labels from me.
        # The verifications scope is nested in the taggings scope, so it only sees the verifications
        # for the same event and tag as the tagging.
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                verifications: {
                  none: {
                    creator_id: { eq: me }
                  }
                }
              }
            }
          },
          # 2 and 3 are expected because because there are no verifications for the second tag
          2..3, 6..7, 9..10,
          11..15,
          40..43,
          46..53,
          54..57,
          66, 67, 68
        )
      end

      it 'that I have not been exposed to (no labels at all) without a taggings filter' do
        # I kept this test because the behavior without a taggings filter
        # is significantly different from the previous test with a taggings filter.
        # In this example any qualifying verification row excludes the event.
        # This is probably not what you want in most cases.
        expect_matching_events(
          {
            verifications: {
              none: {
                creator_id: { eq: me },
                tag_id: { in: [t1.id, t2.id] }
              }
            }
          },
          5..10,
          11..15,
          40..43,
          46..53,
          54..57,
          68
        )
      end
    end

    context 'when finding events based on what anyone has verified' do
      it 'that no one has verified (or is labelled as skip)' do
        # Work is left while any target tag has no non-skip verification from anyone.
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                verifications: {
                  none: {
                    confirmed: { not_eq: 'skip' }
                  }
                }
              }
            }
          },
          4, 6..7, 9..10,
          11, 15, 31, 35,
          39, 43,
          46..53,
          56, 60,
          62..64, 66, 68
        )
      end

      it 'that anyone has verified (or not labelled as skip)' do
        expect_matching_events(
          {
            verifications: {
              any: { confirmed: { not_eq: 'skip' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          1..4,
          12..14, 16..30, 32..34,
          36..38, 40..42, 44..45,
          54..55, 57..59, 61,
          62..63, 65..68,
          69..72
        )
      end

      it 'that anyone has labeled as correct' do
        expect_matching_events(
          {
            verifications: {
              any: { confirmed: { eq: 'correct' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          1, 3, 4,
          12, 16..20, 22, 27, 32,
          36, 40, 44, 45,
          57, 61,
          62..63, 65..68,
          69, 72
        )
      end

      it 'that anyone has labeled as incorrect' do
        expect_matching_events(
          {
            verifications: {
              any: { confirmed: { eq: 'incorrect' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          2,
          13, 18, 21..25, 28, 33,
          37, 41, 44, 45,
          54, 58,
          65, 67,
          69, 70
        )
      end

      it 'that anyone has labeled as unsure' do
        expect_matching_events(
          {
            verifications: {
              any: { confirmed: { eq: 'unsure' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          3,
          14, 19, 24, 26..30, 34,
          38, 42,
          55, 59,
          70..71
        )
      end

      it 'that anyone has labeled as skipped' do
        expect_matching_events(
          {
            verifications: {
              any: { confirmed: { eq: 'skip' }, tag_id: { in: [t1.id, t2.id] } }
            }
          },
          4,
          15, 20, 25, 30..35,
          39, 43,
          56, 60,
          62..64, 68,
          71..72
        )
      end

      it 'that anyone has been exposed to (any label including skip)' do
        expect_matching_events(
          {
            verifications: {
              any: { tag_id: { in: [t1.id, t2.id] } }
            }
          },
          1..4,
          12..35,
          36..45,
          54..61,
          62..68,
          69..72
        )
      end

      it 'that no one has been exposed to (no labels at all)' do
        # A label on one target tag does not expose the event's other target tags.
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                verifications: { none: {} }
              }
            }
          },
          6..7, 9..10,
          11,
          46..53,
          66
        )
      end
    end

    context 'when filtering the campaign taggings (other useful filters)' do
      it 'where I have verified every campaign tag (excluding skips) (perfect completion)' do
        # Ignore non-campaign taggings, but require every campaign tagging to have a non-skip verification from me.
        expect_matching_events(
          {
            and: [
              { taggings: { any: { tag_id: { in: [t1.id, t2.id] } } } },
              {
                taggings: {
                  all: {
                    or: [
                      { tag_id: { not_in: [t1.id, t2.id] } },
                      {
                        verifications: {
                          any: {
                            creator_id: { eq: me },
                            confirmed: { not_eq: 'skip' }
                          }
                        }
                      }
                    ]
                  }
                }
              }
            ]
          },
          1,
          16..30,
          36..38, 44..45,
          58..59, 61,
          65
        )
      end

      it 'where reviewers disagree about the same campaign tag' do
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                and: [
                  { verifications: { any: { confirmed: { eq: 'correct' } } } },
                  { verifications: { any: { confirmed: { eq: 'incorrect' } } } }
                ]
              }
            }
          },
          18, 22, 44, 45
        )
      end

      it 'where another user has verified a campaign tag and I still need to' do
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                and: [
                  {
                    verifications: {
                      any: {
                        creator_id: { not_eq: me },
                        confirmed: { not_eq: 'skip' }
                      }
                    }
                  },
                  {
                    verifications: {
                      none: {
                        creator_id: { eq: me },
                        confirmed: { not_eq: 'skip' }
                      }
                    }
                  }
                ]
              }
            }
          },
          2..3, 12..14, 32..34,
          40..42,
          54..55, 57,
          67..68
        )
      end

      it 'where all votes for a campaign tag are correct' do
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                and: [
                  { verifications: { any: {} } },
                  { verifications: { all: { confirmed: { eq: 'correct' } } } }
                ]
              }
            }
          },
          1, 3, 12, 16..17, 36, 40,
          57, 61..63, 65..68
        )
      end

      it 'where a campaign tag has only been skipped' do
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                and: [
                  { verifications: { any: { confirmed: { eq: 'skip' } } } },
                  { verifications: { none: { confirmed: { not_eq: 'skip' } } } }
                ]
              }
            }
          },
          4, 15, 31, 35, 39, 43,
          56, 60,
          62..64, 68
        )
      end

      it 'where a currently tagged campaign tag has a correct verification' do
        expect_matching_events(
          {
            taggings: {
              any: {
                tag_id: { in: [t1.id, t2.id] },
                verifications: {
                  any: { confirmed: { eq: 'correct' } }
                }
              }
            }
          },
          1, 3, 12, 16..20, 22, 27, 32,
          36, 40, 44..45,
          57, 61..63, 65..68
        )
      end

      it 'that has both campaign tags' do
        expect_matching_events(
          {
            and: [
              { taggings: { any: { tag_id: { eq: t1.id } } } },
              { taggings: { any: { tag_id: { eq: t2.id } } } }
            ]
          },
          1..3, 7, 46..53, 62..68
        )
      end
    end
  end
end
