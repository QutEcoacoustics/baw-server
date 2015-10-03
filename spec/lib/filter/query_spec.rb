require 'rails_helper'

def compare_filter_sql(filter, sql_result)
  filter_query = create_filter(filter)
  expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(sql_result.gsub(/\s+/, ''))
end

describe Filter::Query do

  def create_filter(params)
    Filter::Query.new(
        params,
        nil,
        AudioRecording,
        AudioRecording.filter_settings
    )
  end

  # none_relation, direction asc
  # unrecognised filter
  # and, or, not, other (error)
  # range errors (missing from/to, interval), interval outside range?
  context 'error' do

    it 'occurs when a filter is not recognised' do
      expect {
        create_filter(
            {
                filter: {
                    or: {
                        recorded_date: {
                            not_a_real_filter: 'Hello'
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, 'Unrecognised combiner or field name: not_a_real_filter.')
    end

    it 'occurs when or has only 1 entry' do
      expect {
        create_filter(
            {
                filter: {
                    or: {
                        recorded_date: {
                            contains: 'Hello'
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Combiner 'or' must have at least 2 entries, got 1/)
    end

    it 'occurs when not has no entries' do
      expect {
        create_filter(
            {
                filter: {
                    not: {
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, 'Filter hash must have at least 1 entry, got 0.')
    end

    it 'occurs when or has no entries' do
      expect {
        create_filter(
            {
                filter: {
                    or: {
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Filter hash must have at least 1 entry, got 0/)
    end

    it 'occurs when not has more than one field' do
      expect {
        create_filter(
            {
                filter: {
                    not: {
                        recorded_date: {
                            contains: 'Hello'
                        },
                        site_id: {
                            contains: 'Hello'
                        }
                    }
                }
            }
        ).query_full
      }.to_not raise_error
    end

    it 'occurs when not has more than one filter' do
      expect {
        create_filter(
            {
                filter: {
                    not: {
                        recorded_date: {
                            contains: 'Hello',
                            eq: 2
                        }
                    }
                }
            }
        ).query_full
      }.to_not raise_error
    end

    it 'occurs when a combiner is not recognised with valid filters' do
      expect {
        create_filter(
            {
                filter: {
                    not_a_valid_combiner: {
                        recorded_date: {
                            contains: 'Hello'
                        },
                        site_id: {
                            contains: 'Hello'
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Unrecognised combiner or field name: not_a_valid_combiner/)
    end

#
    it "occurs when a range is missing 'from'" do
      expect {
        create_filter(
            {
                filter: {
                    and: {
                        site_id: {
                            range: {
                                to: 200
                            }
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Range filter missing 'from'/)
    end

    it "occurs when a range is missing 'to'" do
      expect {
        create_filter(
            {
                filter: {
                    and: {
                        site_id: {
                            range: {
                                from: 200
                            }
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Range filter missing 'to'/)
    end

    it 'occurs when a range has from/to and interval' do
      expect {
        create_filter(
            {
                filter: {
                    and: {
                        site_id: {
                            range: {
                                from: 200,
                                to: 200,
                                interval: '[1,2]'
                            }
                        }}
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, "Range filter must use either ('from' and 'to') or ('interval'), not both.")
    end

    it 'occurs when a range has no recognised properties' do
      expect {
        create_filter(
            {
                filter: {
                    and: {
                        site_id: {
                            range: {
                                ignored_in_a_range: '[34,34]'
                            }
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Range filter was not valid/)
    end

    it 'occurs when a property has no filters' do
      expect {
        create_filter(
            {
                filter: {
                    or: {
                        site_id: {
                        }
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Filter hash must have at least 1 entry, got 0/)
    end

    it 'occurs when projection includes invalid field' do
      expect {
        create_filter(
            {
                projection: {
                    include: [
                        :recorded_date,
                        :site_id,
                        :does_not_exist
                    ]
                },
                filter: {
                    site_id: {
                        eq: 5
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /, got does_not_exist/)
    end

    it 'occurs when projection includes duplicate fields' do
      expect {
        create_filter(
            {
                projection: {
                    include: [
                        :recorded_date,
                        :site_id,
                        :site_id
                    ]
                },
                filter: {
                    site_id: {
                        eq: 5
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Must not contain duplicate fields/)
    end

    it 'occurs when projection has both include and exclude' do
      expect {
        create_filter(
            {
                projection: {
                    include: [
                        :recorded_date,
                        :site_id
                    ],
                    exclude: [
                        :recorded_date,
                        :site_id
                    ]
                },
                filter: {
                    site_id: {
                        eq: 5
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Projections hash must have exactly 1 entry, got 2/)
    end

    it 'occurs when projection has empty include' do
      expect {
        create_filter(
            {
                projection: {
                    include: []
                },
                filter: {
                    site_id: {
                        eq: 5
                    }
                }
            }
        ).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, /Include must contain at least one field/)
    end

    it 'occurs with a deformed \'in\' filter' do
      filter_params = {'filter' => {'siteId' => {'in' => [{'customLatitude' => nil, 'customLongitude' => nil, 'description' => nil, 'id' => 508, 'locationObfuscated' => true, 'name' => 'Site 1', 'projectIds' => [397], 'links' => ['http://example.com/projects/397/sites/508']}, {'customLatitude' => nil, 'customLongitude' => nil, 'description' => nil, 'id' => 400, 'locationObfuscated' => true, 'name' => 'Site 2', 'projectIds' => [397], 'links' => ['http://example.com/projects/397/sites/400']}, {'customLatitude' => nil, 'customLongitude' => nil, 'description' => nil, 'id' => 402, 'locationObfuscated' => true, 'name' => 'Site 3', 'projectIds' => [397], 'links' => ['http://example.com/projects/397/sites/402']}, {'customLatitude' => nil, 'customLongitude' => nil, 'description' => nil, 'id' => 399, 'locationObfuscated' => true, 'name' => 'Site 4', 'projectIds' => [397, 469], 'links' => ['http://example.com/projects/397/sites/399', 'http://example.com/projects/469/sites/399']}, {'customLatitude' => nil, 'customLongitude' => nil, 'description' => nil, 'id' => 401, 'locationObfuscated' => true, 'name' => 'Site 5', 'projectIds' => [397], 'links' => ['http://example.com/projects/397/sites/401']}, {'customLatitude' => nil, 'customLongitude' => nil, 'description' => nil, 'id' => 398, 'locationObfuscated' => true, 'name' => 'Site 6', 'projectIds' => [397, 469], 'links' => ['http://example.com/projects/397/sites/398', 'http://example.com/projects/469/sites/398']}]}}, 'projection' => {'include' => ['id', 'siteId', 'durationSeconds', 'recordedDate']}}

      expect {
        create_filter(filter_params).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, 'Array values cannot be hashes.')
    end

    it 'occurs for an invalid range filter' do
      filter_params = {"filter" => {"durationSeconds" => {"inRange" => "(5,6)"}}}
      expect {
        create_filter(filter_params).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, "Range filter must be {'from': 'value', 'to': 'value'} or {'interval': 'value'} got (5,6)")
    end

  end

  context 'projection' do

    it 'using include' do
      request_body_obj = {
          projection: {
              include: [
                  :recorded_date,
                  :site_id
              ]
          },
          filter: {
              site_id: {
                  eq: 5
              }
          }
      }
      complex_result = "SELECT\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"site_id\" \
FROM\"audio_recordings\" \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND\"audio_recordings\".\"site_id\"=5 \
ORDERBY\"audio_recordings\".\"recorded_date\"DESCLIMIT25OFFSET0"
      compare_filter_sql(request_body_obj, complex_result)
    end

    it 'using exclude' do
      request_body_obj = {
          projection: {
              exclude: [
                  :uuid, :recorded_date, :site_id,
                  :sample_rate_hertz, :channels, :bit_rate_bps, :media_type,
                  :data_length_bytes, :status, :created_at, :updated_at
              ]
          },
          filter: {
              site_id: {
                  eq: 5
              }
          }
      }
      complex_result =
          "SELECT\"audio_recordings\".\"id\", \
          \"audio_recordings\".\"duration_seconds\" \
FROM\"audio_recordings\" \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND\"audio_recordings\".\"site_id\"=5 \
ORDERBY\"audio_recordings\".\"recorded_date\"DESCLIMIT25OFFSET0"
      compare_filter_sql(request_body_obj, complex_result)
    end

#     it 'using include_aggregate and group_by' do
#       request_body_obj = {
#           projection: {
#               include_aggregate: {
#                   recorded_date: {
#                       extract: :month
#                   },
#                   site_id: :sum,
#                   status: nil,
#               },
#               group_by: [:status]
#           }
#       }
#       complex_result =
#           "SELECT \
# EXTRACT(month,\"audio_recordings\".\"recorded_date\"), \
# sum(\"audio_recordings\".\"site_id\"), \
#           \"audio_recordings\".\"site_id\" \
# FROM\"audio_recordings\" \
# GROUPBY\"audio_recordings\".\"status\""
#       compare_filter_sql(request_body_obj, complex_result)
#     end

  end

  context 'complex query' do

    it 'generates expected SQL' do
      #Sample POST url and json body
      #POST /audio_recordings/filter?filter_notes=hello&filter_partial_match=testing_testing
      #POST /audio_recordings/filter?filter_notes=hello&filter_channels=28&filter_partial_match=testing_testing

      complex_sample =
          {
              filter: {
                  and: {
                      site_id: {
                          less_than: 123456,
                          greater_than: 9876,
                          in: [
                              1,
                              2,
                              3
                          ],
                          range: {
                              from: 100,
                              to: 200
                          }
                      },
                      status: {
                          greater_than_or_equal: 4567,
                          contains: 'contain text',
                          starts_with: 'starts with text',
                          ends_with: 'ends with text',
                          range: {
                              interval: '[123, 128]'
                          },

                      },
                      or: {
                          duration_seconds: {
                              not_eq: 40
                          },
                          not: {
                              channels: {
                                  less_than_or_equal: 9999
                              }
                          }
                      }
                  },
                  'audio_events.is_reference' => {
                      eq: true
                  },
                  or: {
                      recorded_date: {
                          contains: 'Hello'
                      },

                      media_type: {
                          ends_with: 'world'
                      },

                      duration_seconds: {
                          eq: 60,
                          lteq: 70,
                          equal: 50,
                          gteq: 80
                      },
                      channels: {
                          eq: 1,
                          less_than_or_equal: 8888
                      },
                      'sites.id' => {
                          eq: 5
                      }
                  },
                  not: {
                      duration_seconds: {
                          not_eq: 140
                      },
                      'tags.text' => {
                          contains: 'koala'
                      }
                  }
              },
              projection: {
                  include: [
                      :recorded_date,
                      :site_id,
                      :duration_seconds,
                      :media_type
                  ]
              },
              sorting: {
                  order_by: 'duration_seconds',
                  direction: 'desc'
              },
              paging: {
                  page: 1,
                  items: 10,
              },
              filter_status: 'hello',
              filter_channels: 28,
              filter_partial_match: 'testing_testing'
          }

      complex_result =
          "SELECT\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"site_id\", \
          \"audio_recordings\".\"duration_seconds\",\"audio_recordings\".\"media_type\" \
FROM\"audio_recordings\" \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND(\"audio_recordings\".\"site_id\"<123456 \
AND\"audio_recordings\".\"site_id\">9876 \
AND\"audio_recordings\".\"site_id\"IN(1,2,3) \
AND\"audio_recordings\".\"site_id\">=100 \
AND\"audio_recordings\".\"site_id\"<200 \
AND\"audio_recordings\".\"status\">='4567' \
AND\"audio_recordings\".\"status\"ILIKE'%containtext%' \
AND\"audio_recordings\".\"status\"ILIKE'startswithtext%' \
AND\"audio_recordings\".\"status\"ILIKE'%endswithtext' \
AND\"audio_recordings\".\"status\">='123' \
AND\"audio_recordings\".\"status\"<='128' \
AND(\"audio_recordings\".\"duration_seconds\"!=40 \
ORNOT(\"audio_recordings\".\"channels\"<=9999))) \
AND\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\" \
WHERE\"audio_events\".\"is_reference\"='t') \
AND((((((((\"audio_recordings\".\"recorded_date\"ILIKE'%Hello%' \
OR\"audio_recordings\".\"media_type\"ILIKE'%world') \
OR\"audio_recordings\".\"duration_seconds\"=60) \
OR\"audio_recordings\".\"duration_seconds\"<=70) \
OR\"audio_recordings\".\"duration_seconds\"=50) \
OR\"audio_recordings\".\"duration_seconds\">=80) \
OR\"audio_recordings\".\"channels\"=1) \
OR\"audio_recordings\".\"channels\"<=8888) \
OR\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\" \
WHERE\"sites\".\"id\"=5)) \
AND( \
NOT(\"audio_recordings\".\"duration_seconds\"!=140)) \
AND( \
NOT(\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\" \
LEFTOUTERJOIN\"audio_events_tags\"ON\"audio_events\".\"id\"=\"audio_events_tags\".\"audio_event_id\" \
LEFTOUTERJOIN\"tags\"ON\"audio_events_tags\".\"tag_id\"=\"tags\".\"id\" \
WHERE\"tags\".\"text\"ILIKE'%koala%'))) \
AND(\"audio_recordings\".\"media_type\"ILIKE'%testing\\_testing%' \
OR\"audio_recordings\".\"status\"ILIKE'%testing\\_testing%') \
AND(\"audio_recordings\".\"status\"='hello' \
AND\"audio_recordings\".\"channels\"=28) \
ORDERBY\"audio_recordings\".\"duration_seconds\"DESC \
LIMIT10OFFSET0"

      compare_filter_sql(complex_sample, complex_result)

      @permission = FactoryGirl.create(:write_permission)
      user = @permission.user
      user_id = user.id

      complex_result_2 =
          "SELECT\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"site_id\",\"audio_recordings\".\"duration_seconds\",\"audio_recordings\".\"media_type\"FROM\"audio_recordings\"INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_recordings\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\"))))AND(\"audio_recordings\".\"site_id\"<123456AND\"audio_recordings\".\"site_id\">9876AND\"audio_recordings\".\"site_id\"IN(1,2,3)AND\"audio_recordings\".\"site_id\">=100AND\"audio_recordings\".\"site_id\"<200AND\"audio_recordings\".\"status\">='4567'AND\"audio_recordings\".\"status\"ILIKE'%containtext%'AND\"audio_recordings\".\"status\"ILIKE'startswithtext%'AND\"audio_recordings\".\"status\"ILIKE'%endswithtext'AND\"audio_recordings\".\"status\">='123'AND\"audio_recordings\".\"status\"<='128'AND(\"audio_recordings\".\"duration_seconds\"!=40ORNOT(\"audio_recordings\".\"channels\"<=9999)))AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"WHERE\"audio_events\".\"is_reference\"='t')AND((((((((\"audio_recordings\".\"recorded_date\"ILIKE'%Hello%'OR\"audio_recordings\".\"media_type\"ILIKE'%world')OR\"audio_recordings\".\"duration_seconds\"=60)OR\"audio_recordings\".\"duration_seconds\"<=70)OR\"audio_recordings\".\"duration_seconds\"=50)OR\"audio_recordings\".\"duration_seconds\">=80)OR\"audio_recordings\".\"channels\"=1)OR\"audio_recordings\".\"channels\"<=8888)OR\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\"WHERE\"sites\".\"id\"=5))AND(NOT(\"audio_recordings\".\"duration_seconds\"!=140))AND(NOT(\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"LEFTOUTERJOIN\"audio_events_tags\"ON\"audio_events\".\"id\"=\"audio_events_tags\".\"audio_event_id\"LEFTOUTERJOIN\"tags\"ON\"audio_events_tags\".\"tag_id\"=\"tags\".\"id\"WHERE\"tags\".\"text\"ILIKE'%koala%')))AND(\"audio_recordings\".\"media_type\"ILIKE'%testing\\_testing%'OR\"audio_recordings\".\"status\"ILIKE'%testing\\_testing%')AND(\"audio_recordings\".\"status\"='hello'AND\"audio_recordings\".\"channels\"=28)ORDERBY\"audio_recordings\".\"recorded_date\"DESC,\"audio_recordings\".\"duration_seconds\"DESCLIMIT10OFFSET0"



      filter_query = Filter::Query.new(
          complex_sample,
          Access::Query.audio_recordings(user, Access::Core.levels_allow),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(complex_result_2.gsub(/\s+/, ''))

    end
  end

  context 'with joins' do

    it 'simple audio_recordings query' do
      request_body_obj = {
          projection: {
              exclude: [
                  :uuid, :recorded_date, :site_id,
                  :sample_rate_hertz, :channels, :bit_rate_bps, :media_type,
                  :data_length_bytes, :status, :created_at, :updated_at
              ]
          },
          filter: {
              'sites.id' => {
                  eq: 5
              },
              'audio_events.is_reference' => {
                  eq: true
              },
              'tags.text' => {
                  contains: 'koala'
              }
          }
      }
      complex_result =
          "SELECT\"audio_recordings\".\"id\",\"audio_recordings\".\"duration_seconds\" \
FROM\"audio_recordings\" \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\" \
WHERE\"sites\".\"id\"=5) \
AND\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\" \
WHERE\"audio_events\".\"is_reference\"='t') \
AND\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\" \
LEFTOUTERJOIN\"audio_events_tags\"ON\"audio_events\".\"id\"=\"audio_events_tags\".\"audio_event_id\" \
LEFTOUTERJOIN\"tags\"ON\"audio_events_tags\".\"tag_id\"=\"tags\".\"id\" \
WHERE\"tags\".\"text\"ILIKE'%koala%') \
ORDERBY\"audio_recordings\".\"recorded_date\"DESC \
LIMIT25OFFSET0"

      compare_filter_sql(request_body_obj, complex_result)

      @permission = FactoryGirl.create(:write_permission)
      user = @permission.user
      user_id = user.id

      complex_result_2 =
          "SELECT\"audio_recordings\".\"id\",\"audio_recordings\".\"duration_seconds\"FROM\"audio_recordings\"INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_recordings\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\"))))AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\"WHERE\"sites\".\"id\"=5)AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"WHERE\"audio_events\".\"is_reference\"='t')AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"LEFTOUTERJOIN\"audio_events_tags\"ON\"audio_events\".\"id\"=\"audio_events_tags\".\"audio_event_id\"LEFTOUTERJOIN\"tags\"ON\"audio_events_tags\".\"tag_id\"=\"tags\".\"id\"WHERE\"tags\".\"text\"ILIKE'%koala%')ORDERBY\"audio_recordings\".\"recorded_date\"DESCLIMIT25OFFSET0"

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_recordings(user, Access::Core.levels_allow),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(complex_result_2.gsub(/\s+/, ''))

    end
  end

  context 'calculated field' do
    it 'audio_event.duration_seconds in filter' do
      request_body_obj = {
          filter: {
              duration_seconds: {
                  gt: 3
              }
          }
      }

      @permission = FactoryGirl.create(:write_permission)
      user = @permission.user
      user_id = user.id

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_events(user, Access::Core.levels_allow),
          AudioEvent,
          AudioEvent.filter_settings
      )

      expected_sql =
          "SELECT\"audio_events\".\"id\",\"audio_events\".\"audio_recording_id\",\"audio_events\".\"start_time_seconds\",\"audio_events\".\"end_time_seconds\",\"audio_events\".\"low_frequency_hertz\",\"audio_events\".\"high_frequency_hertz\",\"audio_events\".\"is_reference\",\"audio_events\".\"creator_id\",\"audio_events\".\"updated_at\",\"audio_events\".\"created_at\"FROM\"audio_events\"INNERJOIN\"audio_recordings\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"AND(\"audio_recordings\".\"deleted_at\"ISNULL)INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_events\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\")))OREXISTS(SELECT1FROM\"audio_events\"\"ae_ref\"WHERE\"ae_ref\".\"deleted_at\"ISNULLAND\"ae_ref\".\"is_reference\"='t'AND\"ae_ref\".\"id\"=\"audio_events\".\"id\"))AND((\"audio_events\".\"end_time_seconds\"-\"audio_events\".\"start_time_seconds\")>3)ORDERBY\"audio_events\".\"id\"DESC,\"audio_events\".\"created_at\"DESCLIMIT25OFFSET0"


      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(expected_sql.gsub(/\s+/, ''))

    end

    it 'audio_event.duration_seconds for sorting' do
      request_body_obj = {
          filter: {
              duration_seconds: {
                  gt: 3
              }
          },
          sorting: {
              orderBy: :duration_seconds,
              direction: :asc
          }
      }

      @permission = FactoryGirl.create(:write_permission)
      user = @permission.user
      user_id = user.id

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_events(user, Access::Core.levels_allow),
          AudioEvent,
          AudioEvent.filter_settings
      )

      expected_sql =
          "SELECT\"audio_events\".\"id\",\"audio_events\".\"audio_recording_id\",\"audio_events\".\"start_time_seconds\",\"audio_events\".\"end_time_seconds\",\"audio_events\".\"low_frequency_hertz\",\"audio_events\".\"high_frequency_hertz\",\"audio_events\".\"is_reference\",\"audio_events\".\"creator_id\",\"audio_events\".\"updated_at\",\"audio_events\".\"created_at\"FROM\"audio_events\"INNERJOIN\"audio_recordings\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"AND(\"audio_recordings\".\"deleted_at\"ISNULL)INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_events\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\")))OREXISTS(SELECT1FROM\"audio_events\"\"ae_ref\"WHERE\"ae_ref\".\"deleted_at\"ISNULLAND\"ae_ref\".\"is_reference\"='t'AND\"ae_ref\".\"id\"=\"audio_events\".\"id\"))AND((\"audio_events\".\"end_time_seconds\"-\"audio_events\".\"start_time_seconds\")>3)ORDERBY\"audio_events\".\"id\"DESC,(\"audio_events\".\"end_time_seconds\"-\"audio_events\".\"start_time_seconds\")ASCLIMIT25OFFSET0"


      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(expected_sql.gsub(/\s+/, ''))

    end

  end

  context 'ensures a site in more than one project' do

    it 'does not duplicate audio_events' do
      user = FactoryGirl.create(:user)
      permission = FactoryGirl.create(:write_permission, creator: user, user: user)

      site = permission.project.sites.first

      project1 = permission.project
      project2 = FactoryGirl.create(:project, creator: user, sites: [site])
      permission2 = FactoryGirl.create(:permission, creator: user, project: project2, user: user, level: 'writer')

      project3 = FactoryGirl.create(:project, creator: user, sites: [site])
      permission3 = FactoryGirl.create(:permission, creator: user, project: project3, user: user, level: 'writer')

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_events(user, Access::Core.levels_allow),
          AudioEvent,
          AudioEvent.filter_settings
      )

      ids = filter_query.query_full.pluck(:id)

      expect(ids).to match_array(AudioEvent.all.pluck(:id))
    end

    it 'does not duplicate audio_event_comments' do
      user = FactoryGirl.create(:user)
      permission = FactoryGirl.create(:write_permission, creator: user, user: user)

      site = permission.project.sites.first

      project1 = permission.project
      project2 = FactoryGirl.create(:project, creator: user, sites: [site])
      permission2 = FactoryGirl.create(:permission, creator: user, project: project2, user: user, level: 'writer')

      project3 = FactoryGirl.create(:project, creator: user, sites: [site])
      permission3 = FactoryGirl.create(:permission, creator: user, project: project3, user: user, level: 'writer')

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::Query.comments(user, Access::Core.levels_allow),
          AudioEventComment,
          AudioEventComment.filter_settings
      )

      ids = filter_query.query_full.pluck(:id)

      expect(ids).to match_array(AudioEventComment.all.pluck(:id))
    end
  end

  context 'gets projects' do
    it 'inaccessible' do
      user = FactoryGirl.create(:user)
      permission = FactoryGirl.create(:read_permission, creator: user, user: user)
      project_no_access = FactoryGirl.create(:project)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_inaccessible = Filter::Query.new(
          request_body_obj,
          Access::Query.projects_inaccessible(user),
          Project,
          Project.filter_settings
      )

      ids_inaccessible = filter_query_inaccessible.query_full.pluck(:id)
      expect(ids_inaccessible).to match_array([project_no_access.id])
    end

    it 'accessible' do
      user = FactoryGirl.create(:user)
      permission = FactoryGirl.create(:read_permission, creator: user, user: user)

      project_access = permission.project
      project_no_access = FactoryGirl.create(:project)
      access_via_created = FactoryGirl.create(:project, creator: user)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_accessible = Filter::Query.new(
          request_body_obj,
          Access::Query.projects_accessible(user),
          Project,
          Project.filter_settings
      )

      ids_accessible = filter_query_accessible.query_full.pluck(:id)
      expect(ids_accessible).to match_array([project_access.id, access_via_created.id])
    end

  end

  context 'nested indexes properly filtered' do

    it 'restricts sites to project' do
      user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission2 = FactoryGirl.create(:read_permission, creator: user, user: user)
      site2 = permission2.project.sites.first

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::Query.project_sites(permission2.project, user, Access::Core.levels_allow),
          Site,
          Site.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [site2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts sites to those in projects that cannot be accessed' do
      user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission2 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission3 = FactoryGirl.create(:read_permission)
      project3 = permission3.project
      site3 = project3.sites.first

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::Query.project_sites(project3, user, Access::Core.levels_deny),
          Site,
          Site.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [site3.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts permissions to project' do
      user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission2 = FactoryGirl.create(:read_permission, creator: user, user: user)
      project2 = permission2.project

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::Query.project_permissions(project2),
          Permission,
          Permission.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [permission2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts audio events to audio recording' do
      user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission2 = FactoryGirl.create(:read_permission, creator: user, user: user)
      audio_recording2 = permission2.project.sites.first.audio_recordings.first
      audio_event2 = audio_recording2.audio_events.first

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_recording_audio_events(audio_recording2, user),
          AudioEvent,
          AudioEvent.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [audio_event2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    # TODO
    # it 'restricts taggings to audio event and audio recording' do
    #
    # end

    # TODO
    # it 'restricts tags to audio event and audio recording' do
    #
    # end

    it 'restricts comments to audio event' do
      user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission2 = FactoryGirl.create(:read_permission, creator: user, user: user)
      audio_recording2 = permission2.project.sites.first.audio_recordings.first
      audio_event2 = audio_recording2.audio_events.first
      comment2 = audio_event2.comments.first

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_event_comments(audio_event2, user),
          AudioEventComment,
          AudioEventComment.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [comment2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts comments to audio events in projects that can not be accessed' do
      user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: user, user: user)
      permission2 = FactoryGirl.create(:read_permission)
      audio_recording2 = permission2.project.sites.first.audio_recordings.first
      audio_event2 = audio_recording2.audio_events.first
      comment2 = audio_event2.comments.first

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::Query.audio_event_comments(audio_event2, user, Access::Core.levels_deny),
          AudioEventComment,
          AudioEventComment.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [comment2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

  end

end
