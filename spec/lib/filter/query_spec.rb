require 'rails_helper'

def compare_filter_sql(filter, sql_result)
  filter_query = create_filter(filter)
  expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(sql_result.gsub(/\s+/, ''))
  filter_query
end

describe Filter::Query do

  create_entire_hierarchy

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

    it 'generates expected filter and SQL' do

      # combined POST body and query string parameters (would not usually happen)
      posted_filter = {
          filter: {
              and: {
                  site_id: {
                      less_than: 123456,
                      greater_than: 9876,
                      in: [1, 2, 3],
                      range: {
                          from: 100,
                          to: 200
                      }
                  },
                  status: {
                      greater_than_or_equal: '4567',
                      contains: 'contain text',
                      starts_with: 'starts with text',
                      ends_with: 'ends with text',
                      range: {
                          interval: '[123, 128]'
                      },
                      eq: 'will be overridden'
                  },
                  duration_seconds: {
                      in: [4, 5, 6]
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
                      eq: '2016-04-24 12:00:00'
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
                  },
                  status: {
                      contains: 'will be overridden'
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
          filter_status: 'hello_status',
          filter_channels: 28,
          filter_duration_seconds: 123,
          filter_partial_match: 'testing_testing'
      }

      expected_filter = {
          and: {
              site_id: {
                  less_than: 123456,
                  greater_than: 9876,
                  in: [1, 2, 3],
                  range: {
                      from: 100,
                      to: 200
                  }
              },
              status: {
                  greater_than_or_equal: '4567',
                  contains: 'contain text',
                  starts_with: 'starts with text',
                  ends_with: 'ends with text',
                  range: {
                      interval: '[123, 128]'
                  },
                  eq: 'hello_status'
              },
              duration_seconds: {
                  in: [4, 5, 6],
                  eq: 123
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
          'audio_events.is_reference'.to_sym => {
              eq: true
          },
          channels: {
              eq: 28
          },
          or: {
              recorded_date: {
                  eq: '2016-04-24 12:00:00'
              },

              media_type: {
                  ends_with: 'world',
                  contains: 'testing_testing'
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
              'sites.id'.to_sym => {
                  eq: 5
              },
              status: {
                  contains: 'testing_testing'
              }
          },
          not: {
              duration_seconds: {
                  not_eq: 140
              },
              'tags.text'.to_sym => {
                  contains: 'koala'
              }
          }
      }

      user = writer_user
      filter_query = Filter::Query.new(
          posted_filter,
          Access::Query.audio_recordings(user, Access::Core.levels_allow),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter_query.filter).to eq(expected_filter)

      user_id = user.id
      complex_result_2 =
          "SELECT\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"site_id\",\"audio_recordings\".\"duration_seconds\",\"audio_recordings\".\"media_type\" \
FROM\"audio_recordings\" \
INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\" \
AND(\"sites\".\"deleted_at\"ISNULL) \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND(EXISTS( \
SELECT1FROM\"projects_sites\" \
WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\" \
ANDEXISTS(( \
SELECT1FROM\"projects\" \
WHERE\"projects\".\"deleted_at\"ISNULL \
AND\"projects\".\"creator_id\"=#{user_id} \
AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALL \
SELECT1FROM\"permissions\" \
WHERE\"permissions\".\"user_id\"=#{user_id} \
AND\"permissions\".\"level\"IN('reader','writer','owner') \
AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\")))) \
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
AND\"audio_recordings\".\"status\"='hello_status' \
AND\"audio_recordings\".\"duration_seconds\"IN(4,5,6) \
AND\"audio_recordings\".\"duration_seconds\"=123 \
AND(\"audio_recordings\".\"duration_seconds\"!=40 \
ORNOT(\"audio_recordings\".\"channels\"<=9999))) \
AND\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\" \
LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\" \
WHERE\"audio_events\".\"is_reference\"='t') \
AND((((((((((\"audio_recordings\".\"recorded_date\"='2016-04-2412:00:00' \
OR\"audio_recordings\".\"media_type\"ILIKE'%world') \
OR\"audio_recordings\".\"media_type\"ILIKE'%testing\\_testing%') \
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
OR\"audio_recordings\".\"status\"ILIKE'%testing\\_testing%') \
AND(NOT(\"audio_recordings\".\"duration_seconds\"!=140)) \
AND(NOT(\"audio_recordings\".\"id\"IN( \
SELECT\"audio_recordings\".\"id\" \
FROM\"audio_recordings\" \
LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\" \
LEFTOUTERJOIN\"audio_events_tags\"ON\"audio_events\".\"id\"=\"audio_events_tags\".\"audio_event_id\" \
LEFTOUTERJOIN\"tags\"ON\"audio_events_tags\".\"tag_id\"=\"tags\".\"id\" \
WHERE\"tags\".\"text\"ILIKE'%koala%'))) \
AND\"audio_recordings\".\"channels\"=28 \
ORDERBY\"audio_recordings\".\"recorded_date\"DESC,\"audio_recordings\".\"duration_seconds\"DESC \
LIMIT10OFFSET0"
      
      full_query = filter_query.query_full
      expect(full_query.to_sql.gsub(/\s+/, '')).to eq(complex_result_2.gsub(/\s+/, ''))
      
      # ensure query can be run (it obvs won't return anything)
      expect(full_query.pluck(:recorded_date)).to eq([])
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

      user = writer_user
      user_id = user.id

      complex_result_2 =
          "SELECT\"audio_recordings\".\"id\",\"audio_recordings\".\"duration_seconds\"FROM\"audio_recordings\"INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_recordings\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\"))))AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\"WHERE\"sites\".\"id\"=5)AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"WHERE\"audio_events\".\"is_reference\"='t')AND\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"audio_events\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"LEFTOUTERJOIN\"audio_events_tags\"ON\"audio_events\".\"id\"=\"audio_events_tags\".\"audio_event_id\"LEFTOUTERJOIN\"tags\"ON\"audio_events_tags\".\"tag_id\"=\"tags\".\"id\"WHERE\"tags\".\"text\"ILIKE'%koala%')ORDERBY\"audio_recordings\".\"recorded_date\"DESCLIMIT25OFFSET0"

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_recordings(user, Access::Core.levels),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(complex_result_2.gsub(/\s+/, ''))

    end

    it 'audio_recording with projects' do
      request_body_obj = {
          filter: {
              and: {
                  'projects.id' => {
                      less_than: 123456
                  },
                  duration_seconds: {
                      not_eq: 40
                  }
              }
          },
          projection: {
              include: [:id, :site_id, :duration_seconds, :recorded_date, :created_at]
          },
          paging: {
              items: 20,
              page: 1
          },
          sort: {
              order_by: "created_at",
              direction: "desc"
          }
      }
      complex_result =
          "SELECT\"audio_recordings\".\"id\", \
          \"audio_recordings\".\"site_id\", \
          \"audio_recordings\".\"duration_seconds\", \
          \"audio_recordings\".\"recorded_date\", \
          \"audio_recordings\".\"created_at\" \
FROM\"audio_recordings\" \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND(\"audio_recordings\".\"id\"IN \
(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\" \
LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\" \
LEFTOUTERJOIN\"projects_sites\"ON\"sites\".\"id\"=\"projects_sites\".\"site_id\" \
LEFTOUTERJOIN\"projects\"ON\"projects_sites\".\"project_id\"=\"projects\".\"id\" \
WHERE\"projects\".\"id\"<123456) \
AND\"audio_recordings\".\"duration_seconds\"!=40) \
ORDERBY\"audio_recordings\".\"recorded_date\" \
DESCLIMIT20OFFSET0"

      compare_filter_sql(request_body_obj, complex_result)

      user = writer_user
      user_id = user.id

      complex_result_2 =
          "SELECT\"audio_recordings\".\"id\",\"audio_recordings\".\"site_id\",\"audio_recordings\".\"duration_seconds\",\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"created_at\"FROM\"audio_recordings\"INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_recordings\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\"))))AND(\"audio_recordings\".\"id\"IN(SELECT\"audio_recordings\".\"id\"FROM\"audio_recordings\"LEFTOUTERJOIN\"sites\"ON\"audio_recordings\".\"site_id\"=\"sites\".\"id\"LEFTOUTERJOIN\"projects_sites\"ON\"sites\".\"id\"=\"projects_sites\".\"site_id\"LEFTOUTERJOIN\"projects\"ON\"projects_sites\".\"project_id\"=\"projects\".\"id\"WHERE\"projects\".\"id\"<123456)AND\"audio_recordings\".\"duration_seconds\"!=40)ORDERBY\"audio_recordings\".\"recorded_date\"DESCLIMIT20OFFSET0"

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_recordings(user, Access::Core.levels),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(complex_result_2.gsub(/\s+/, ''))
    end

    it 'analysis_jobs_items - system, using a virtual table' do

      request_body_obj = {
          filter: {
              'audio_recordings.duration_seconds': {
                  gteq: audio_recording.duration_seconds
              },
          },
          projection: {
              include: [:analysis_job_id, :audio_recording_id, :status]
          },
          paging: {
              items: 20,
              page: 2
          }
      }

      user = writer_user
      user_id = user.id

      complex_result = <<-SQL
SELECT
  "analysis_jobs_items"."analysis_job_id",
  "analysis_jobs_items"."audio_recording_id",
  "analysis_jobs_items"."status"
FROM (SELECT
  "tmp_audio_recordings_generator"."id" AS "audio_recording_id",
  "analysis_jobs_items"."id",
  "analysis_jobs_items"."analysis_job_id",
  "analysis_jobs_items"."queue_id",
  "analysis_jobs_items"."status",
  "analysis_jobs_items"."created_at",
  "analysis_jobs_items"."queued_at",
  "analysis_jobs_items"."work_started_at",
  "analysis_jobs_items"."completed_at"
FROM "analysis_jobs_items"
  RIGHT
  OUTER JOIN "audio_recordings" "tmp_audio_recordings_generator"
    ON "tmp_audio_recordings_generator"."id" IS NULL
) analysis_jobs_items INNER
  JOIN "audio_recordings"
    ON "audio_recordings"."id" = "analysis_jobs_items"."audio_recording_id"
       AND ("audio_recordings"."deleted_at" IS NULL)
  INNER JOIN "sites"
    ON "sites"."id" = "audio_recordings"."site_id"
       AND ("sites"."deleted_at" IS NULL)
WHERE (EXISTS(SELECT 1
              FROM "projects_sites"
              WHERE "sites"."id" = "projects_sites"."site_id" AND EXISTS((SELECT 1
              FROM "projects"
              WHERE "projects"."deleted_at" IS NULL AND "projects"."creator_id" = #{user_id}
                AND "projects_sites"."project_id" = "projects"."id"
              UNION ALL
              SELECT 1
              FROM "permissions"
              WHERE "permissions"."user_id" = #{user_id} AND "permissions"."level" IN ('reader', 'writer', 'owner')
                AND "projects_sites"."project_id" = "permissions"."project_id"))))
      AND "analysis_jobs_items"."audio_recording_id" IN (
      SELECT "analysis_jobs_items"."audio_recording_id"
        FROM (SELECT "analysis_jobs_items".*
          FROM (SELECT
            "tmp_audio_recordings_generator"."id" AS "audio_recording_id",
            "analysis_jobs_items"."id",
            "analysis_jobs_items"."analysis_job_id",
            "analysis_jobs_items"."queue_id",
            "analysis_jobs_items"."status",
            "analysis_jobs_items"."created_at",
            "analysis_jobs_items"."queued_at",
            "analysis_jobs_items"."work_started_at",
            "analysis_jobs_items"."completed_at"
          FROM "analysis_jobs_items"
            RIGHT OUTER JOIN "audio_recordings" "tmp_audio_recordings_generator"
              ON "tmp_audio_recordings_generator"."id" IS NULL) analysis_jobs_items
            INNER JOIN "audio_recordings"
              ON "audio_recordings"."id" = "analysis_jobs_items"."audio_recording_id"
                AND ("audio_recordings"."deleted_at" IS NULL)) analysis_jobs_items
          LEFT OUTER JOIN "audio_recordings"
            ON "analysis_jobs_items"."audio_recording_id" = "audio_recordings"."id"
      WHERE "audio_recordings"."duration_seconds" >= 60000.0)
ORDER BY
  "analysis_jobs_items"."audio_recording_id" ASC
LIMIT 20
OFFSET 20
SQL

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::Query.analysis_jobs_items(nil, user, true),
          AnalysisJobsItem,
          AnalysisJobsItem.filter_settings(true)
      )

      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(complex_result.gsub(/\s+/, ''))
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

      user = writer_user
      user_id = user.id

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_events(user, Access::Core.levels),
          AudioEvent,
          AudioEvent.filter_settings
      )

      expected_sql =
          "SELECT\"audio_events\".\"id\",\"audio_events\".\"audio_recording_id\",\"audio_events\".\"start_time_seconds\",\"audio_events\".\"end_time_seconds\",\"audio_events\".\"low_frequency_hertz\",\"audio_events\".\"high_frequency_hertz\",\"audio_events\".\"is_reference\",\"audio_events\".\"creator_id\",\"audio_events\".\"updated_at\",\"audio_events\".\"created_at\"FROM\"audio_events\"INNERJOIN\"audio_recordings\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"AND(\"audio_recordings\".\"deleted_at\"ISNULL)INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_events\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\")))OREXISTS(SELECT1FROM\"audio_events\"\"ae_ref\"WHERE\"ae_ref\".\"deleted_at\"ISNULLAND\"ae_ref\".\"is_reference\"='t'AND\"ae_ref\".\"id\"=\"audio_events\".\"id\"))AND((\"audio_events\".\"end_time_seconds\"-\"audio_events\".\"start_time_seconds\")>3)ORDERBY\"audio_events\".\"created_at\"DESCLIMIT25OFFSET0"


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

      user = writer_user
      user_id = user.id

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_events(user, Access::Core.levels),
          AudioEvent,
          AudioEvent.filter_settings
      )

      expected_sql =
          "SELECT\"audio_events\".\"id\",\"audio_events\".\"audio_recording_id\",\"audio_events\".\"start_time_seconds\",\"audio_events\".\"end_time_seconds\",\"audio_events\".\"low_frequency_hertz\",\"audio_events\".\"high_frequency_hertz\",\"audio_events\".\"is_reference\",\"audio_events\".\"creator_id\",\"audio_events\".\"updated_at\",\"audio_events\".\"created_at\"FROM\"audio_events\"INNERJOIN\"audio_recordings\"ON\"audio_recordings\".\"id\"=\"audio_events\".\"audio_recording_id\"AND(\"audio_recordings\".\"deleted_at\"ISNULL)INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_events\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\")))OREXISTS(SELECT1FROM\"audio_events\"\"ae_ref\"WHERE\"ae_ref\".\"deleted_at\"ISNULLAND\"ae_ref\".\"is_reference\"='t'AND\"ae_ref\".\"id\"=\"audio_events\".\"id\"))AND((\"audio_events\".\"end_time_seconds\"-\"audio_events\".\"start_time_seconds\")>3)ORDERBY(\"audio_events\".\"end_time_seconds\"-\"audio_events\".\"start_time_seconds\")ASCLIMIT25OFFSET0"


      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(expected_sql.gsub(/\s+/, ''))

    end

    it 'audio_recording.recorded_end_date in filter' do
      request_body_obj = {
          filter: {
              recorded_end_date: {
                  lt: '2016-03-01T02:00:00',
                  gt: '2016-03-01T01:50:00'
              }
          }
      }

      user = writer_user
      user_id = user.id

      filter_query = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_recordings(user, Access::Core.levels),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expected_sql =
          "SELECT\"audio_recordings\".\"id\",\"audio_recordings\".\"uuid\",\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"site_id\",\"audio_recordings\".\"duration_seconds\",\"audio_recordings\".\"sample_rate_hertz\",\"audio_recordings\".\"channels\",\"audio_recordings\".\"bit_rate_bps\",\"audio_recordings\".\"media_type\",\"audio_recordings\".\"data_length_bytes\",\"audio_recordings\".\"status\",\"audio_recordings\".\"created_at\",\"audio_recordings\".\"updated_at\"FROM\"audio_recordings\"INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL)WHERE(\"audio_recordings\".\"deleted_at\"ISNULL)AND(EXISTS(SELECT1FROM\"projects_sites\"WHERE\"sites\".\"id\"=\"projects_sites\".\"site_id\"ANDEXISTS((SELECT1FROM\"projects\"WHERE\"projects\".\"deleted_at\"ISNULLAND\"projects\".\"creator_id\"=#{user_id}AND\"projects_sites\".\"project_id\"=\"projects\".\"id\"UNIONALLSELECT1FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner')AND\"projects_sites\".\"project_id\"=\"permissions\".\"project_id\"))))AND(\"audio_recordings\".\"recorded_date\"+CAST(\"audio_recordings\".\"duration_seconds\"||'seconds'asinterval)<'2016-03-01T02:00:00')AND(\"audio_recordings\".\"recorded_date\"+CAST(\"audio_recordings\".\"duration_seconds\"||'seconds'asinterval)>'2016-03-01T01:50:00')ORDERBY\"audio_recordings\".\"recorded_date\"DESCLIMIT25OFFSET0"


      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(expected_sql.gsub(/\s+/, ''))

    end

  end

  context 'ensures a site in more than one project' do

    it 'does not duplicate audio_events' do
      user = owner_user

      site = project.sites.first

      project1 = project
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
          Access::ByPermission.audio_events(user, Access::Core.levels),
          AudioEvent,
          AudioEvent.filter_settings
      )

      ids = filter_query.query_full.pluck(:id)

      expect(ids).to match_array(AudioEvent.all.pluck(:id))
    end

    it 'does not duplicate audio_event_comments' do
      user = owner_user

      site = project.sites.first

      project1 = project
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
          Access::ByPermission.audio_event_comments(user, Access::Core.levels),
          AudioEventComment,
          AudioEventComment.filter_settings
      )

      ids = filter_query.query_full.pluck(:id)

      expect(ids).to match_array(AudioEventComment.all.pluck(:id))
    end
  end

  context 'gets projects' do
    it 'inaccessible' do
      the_user = owner_user
      project_no_access = FactoryGirl.create(:project, creator: other_user)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_inaccessible = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.projects(the_user, Access::Core.levels_none),
          Project,
          Project.filter_settings
      )

      ids_inaccessible = filter_query_inaccessible.query_full.pluck(:id)
      expect(ids_inaccessible).to match_array([project_no_access.id])
    end

    it 'accessible' do
      the_user = owner_user

      project_access = project
      project_no_access = FactoryGirl.create(:project)
      access_via_created = FactoryGirl.create(:project, creator: the_user)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_accessible = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.projects(the_user),
          Project,
          Project.filter_settings
      )

      ids_accessible = filter_query_accessible.query_full.pluck(:id)
      expect(ids_accessible).to match_array([project_access.id, access_via_created.id])
    end

  end

  context 'nested indexes properly filtered' do

    it 'restricts sites to project' do
      the_user = owner_user

      project_new = FactoryGirl.create(:project, creator: the_user)
      site2 = FactoryGirl.create(:site, creator: the_user)
      project_new.sites << site2
      project_new.save!

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.sites(the_user, Access::Core.levels, project_new),
          Site,
          Site.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [site2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts sites to those in projects that cannot be accessed' do
      the_user = owner_user

      project2 = FactoryGirl.create(:project, creator: the_user)
      site2 = FactoryGirl.create(:site, creator: the_user)
      project2.sites << site2
      project2.save!

      project3 = FactoryGirl.create(:project, creator: other_user)
      site3 = FactoryGirl.create(:site, creator: other_user)
      project3.sites << site3
      project3.save!

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.sites(the_user, Access::Core.levels_none, project3),
          Site,
          Site.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [site3.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts permissions to project' do
      the_user = FactoryGirl.create(:user)
      permission1 = FactoryGirl.create(:read_permission, creator: the_user, user: the_user)
      permission2 = FactoryGirl.create(:read_permission, creator: the_user, user: the_user)
      project2 = permission2.project

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.permissions(project2),
          Permission,
          Permission.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [permission2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts audio events to audio recording' do
      the_user = owner_user

      project2 = Creation::Common.create_project(the_user)
      site2 = Creation::Common.create_site(the_user, project2)
      audio_recording2 = Creation::Common.create_audio_recording(the_user, the_user, site2)
      audio_event2 = Creation::Common.create_audio_event(the_user, audio_recording2)

      project3 = Creation::Common.create_project(the_user)
      site3 = Creation::Common.create_site(the_user, project3)
      audio_recording3 = Creation::Common.create_audio_recording(the_user, the_user, site3)
      audio_event3 = Creation::Common.create_audio_event(the_user, audio_recording3)

      expect(AudioEvent.count).to eq(3)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_events(the_user, Access::Core.levels, audio_recording2),
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
      the_user = owner_user

      project2 = Creation::Common.create_project(the_user)
      site2 = Creation::Common.create_site(the_user, project2)
      audio_recording2 = Creation::Common.create_audio_recording(the_user, the_user, site2)
      audio_event2 = Creation::Common.create_audio_event(the_user, audio_recording2)
      comment2 = Creation::Common.create_audio_event_comment(the_user, audio_event2)

      project3 = Creation::Common.create_project(the_user)
      site3 = Creation::Common.create_site(the_user, project3)
      audio_recording3 = Creation::Common.create_audio_recording(the_user, the_user, site3)
      audio_event3 = Creation::Common.create_audio_event(the_user, audio_recording3)
      comment3 = Creation::Common.create_audio_event_comment(the_user, audio_event3)

      expect(AudioEventComment.count).to eq(3)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_event_comments(the_user, Access::Core.levels, audio_event2),
          AudioEventComment,
          AudioEventComment.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [comment2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'restricts comments to audio events in projects that can not be accessed' do
      the_user = owner_user
      comment1 = FactoryGirl.create(:audio_event_comment, creator: the_user)
      comment2 = FactoryGirl.create(:audio_event_comment)
      audio_event2 = comment2.audio_event

      expect(AudioEventComment.count).to eq(3)

      request_body_obj = {
          projection: {
              include: [:id]
          }
      }

      filter_query_project2 = Filter::Query.new(
          request_body_obj,
          Access::ByPermission.audio_event_comments(the_user, Access::Core.levels_none, audio_event2),
          AudioEventComment,
          AudioEventComment.filter_settings
      )

      ids_actual = filter_query_project2.query_full.pluck(:id)
      ids_expected = [comment2.id]
      expect(ids_actual).to match_array(ids_expected)
    end

  end

  context 'qsp filter' do

    it 'does not allow fields that do not exist' do
      filter = Filter::Query.new(
          {filter_this_is_not_a_field: 'oops'},
          Script.order(name: :asc).order(created_at: :desc),
          Script,
          Script.filter_settings)
      expect {
        filter.build.parse(filter.filter)
      }.to raise_error(CustomErrors::FilterArgumentError, 'Unrecognised combiner or field name: this_is_not_a_field.')
    end

    it 'allows mapped fields as a generic equality field' do
      audio_event = FactoryGirl.create(
          :audio_event,
          audio_recording: audio_recording,
          start_time_seconds: 10,
          end_time_seconds: 88)

      # simluate
      # GET /audio_recordings/234234/audio_events?start_time_seconds=10&end_time_seconds=88

      filter = Filter::Query.new(
          {filter_start_time_seconds: 10, filter_end_time_seconds: 88},
          Access::Query.audio_recording_audio_events(audio_recording, admin_user),
          AudioEvent,
          AudioEvent.filter_settings
      )

      expect(filter.filter).to eq({and: {start_time_seconds: {eq: 10}, end_time_seconds: {eq: 88}}})

      ids_actual = filter.query_full.pluck(:id)
      ids_expected = [audio_event.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'allows generic equality fields' do
      audio_event = FactoryGirl.create(
          :audio_event,
          audio_recording: audio_recording,
          start_time_seconds: 10,
          end_time_seconds: 88)

      # simluate
      # GET /audio_recordings/234234/audio_events?filter_duration_seconds=78

      filter = Filter::Query.new(
          {filter_duration_seconds: 78},
          Access::Query.audio_recording_audio_events(audio_recording, admin_user),
          AudioEvent,
          AudioEvent.filter_settings
      )

      expect(filter.filter).to eq({duration_seconds: {eq: 78}})

      ids_actual = filter.query_full.pluck(:id)
      ids_expected = [audio_event.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'allows one text partial match field' do
      admin_user_name = admin_user.user_name

      filter = Filter::Query.new(
          {filter_partial_match: admin_user_name},
          User.all,
          User,
          User.filter_settings
      )

      expect(filter.filter).to eq({user_name: {contains: admin_user_name}})

      ids_actual = filter.query_full.pluck(:id)
      ids_expected = [admin_user.id]
      expect(ids_actual).to match_array(ids_expected)
    end


    it 'overrides filter parameters that match generic equality fields' do
      audio_event = FactoryGirl.create(
          :audio_event,
          audio_recording: audio_recording,
          start_time_seconds: 10,
          end_time_seconds: 88)

      filter = Filter::Query.new(
          {filter: {
              duration_seconds: {eq: 78}, start_time_seconds: {eq: 20}
          },
           filter_start_time_seconds: 10, filter_end_time_seconds: 88
          },
          Access::Query.audio_recording_audio_events(audio_recording, admin_user),
          AudioEvent,
          AudioEvent.filter_settings
      )

      # defaults to 'and' when no combiner is specified
      expect(filter.filter).to eq({duration_seconds: {eq: 78}, start_time_seconds: {eq: 10}, end_time_seconds: {eq: 88}})

      ids_actual = filter.query_full.pluck(:id)
      ids_expected = [audio_event.id]
      expect(ids_actual).to match_array(ids_expected)
    end

    it 'overrides filter parameters that match text partial match field' do
      audio_recording = FactoryGirl.create(
          :audio_recording,
          media_type: 'audio/mp3',
          recorded_date: '2012-03-26 07:06:59',
          duration_seconds: 120)

      filter = Filter::Query.new(
          {filter: {
              duration_seconds: {eq: 100},
              or: {media_type: {contains: 'wav'}, status: {contains: 'wav'}}
          },
           filter_duration_seconds: 120,
           filter_partial_match: 'mp3'
          },
          Access::Query.audio_recordings(admin_user),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter.filter).to eq({duration_seconds: {eq: 120}, or: {media_type: {contains: 'mp3'}, status: {contains: 'mp3'}}})

      ids_actual = filter.query_full.pluck(:id)
      ids_expected = [audio_recording.id]
      expect(ids_actual).to match_array(ids_expected)
    end

  end

  context 'available filter items' do

    it 'every item is available' do
      filter_hash = {
          filter: {
              and: {
                  media_type: {
                      # comparison
                      eq: 'm',
                      equal: 'm',
                      not_eq: 'm',
                      not_equal: 'm',
                      lt: 'm',
                      less_than: 'm',
                      not_lt: 'm',
                      not_less_than: 'm',
                      gt: 'm',
                      greater_than: 'm',
                      not_gt: 'm',
                      not_greater_than: 'm',
                      lteq: 'm',
                      less_than_or_equal: 'm',
                      not_lteq: 'm',
                      not_less_than_or_equal: 'm',
                      gteq: 'm',
                      greater_than_or_equal: 'm',
                      not_gteq: 'm',
                      not_greater_than_or_equal: 'm',

                      # subset
                      range: {from: 'm', to: 'm'},
                      in_range: {from: 'm', to: 'm'},
                      not_range: {from: 'm', to: 'm'},
                      not_in_range: {from: 'm', to: 'm'},
                      in: ['m'],
                      not_in: ['m'],
                      contains: 'm',
                      contain: 'm',
                      not_contains: 'm',
                      not_contain: 'm',
                      does_not_contain: 'm',
                      starts_with: 'm',
                      start_with: 'm',
                      not_starts_with: 'm',
                      not_start_with: 'm',
                      does_not_start_with: 'm',
                      ends_with: 'm',
                      end_with: 'm',
                      not_ends_with: 'm',
                      not_end_with: 'm',
                      does_not_end_with: 'm',
                      regex: 'm',
                      regex_match: 'm',
                      matches: 'm',
                      not_regex: 'm',
                      not_regex_match: 'm',
                      does_not_match: 'm',
                      not_match: 'm'
                  }
              }
          }
      }

      filter = Filter::Query.new(
          filter_hash,
          Access::Query.audio_recordings(admin_user),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter.filter).to eq(filter_hash[:filter])

      query = filter.query_full
      expect(query.pluck(:id)).to match_array([])
    end
  end

end
