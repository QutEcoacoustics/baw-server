require 'spec_helper'

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
      }.to raise_error(CustomErrors::FilterArgumentError, /Unrecognised filter not_a_real_filter/)
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
      }.to raise_error(CustomErrors::FilterArgumentError, /Conditions hash must have at least 1 entry, got 0/)
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
      }.to raise_error(CustomErrors::FilterArgumentError, /Conditions hash must have at least 1 entry, got 0/)
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
      }.to raise_error(CustomErrors::FilterArgumentError, /'Not' must have a single combiner or field name, got 2/)
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
      }.to raise_error(CustomErrors::FilterArgumentError, /'Not' must have a single filter, got 2/)
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
      }.to raise_error(CustomErrors::FilterArgumentError, /Conditions hash must have at least 1 entry, got 0/)
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
      filter_params = {'filter' => {'siteId' => {'in' => [{'customLatitude' => nil,'customLongitude' => nil,'description' => nil,'id' => 508,'locationObfuscated' => true,'name' => 'Site 1','projectIds' => [397],'links' => ['http://example.com/projects/397/sites/508']},{'customLatitude' => nil,'customLongitude' => nil,'description' => nil,'id' => 400,'locationObfuscated' => true,'name' => 'Site 2','projectIds' => [397],'links' => ['http://example.com/projects/397/sites/400']},{'customLatitude' => nil,'customLongitude' => nil,'description' => nil,'id' => 402,'locationObfuscated' => true,'name' => 'Site 3','projectIds' => [397],'links' => ['http://example.com/projects/397/sites/402']},{'customLatitude' => nil,'customLongitude' => nil,'description' => nil,'id' => 399,'locationObfuscated' => true,'name' => 'Site 4','projectIds' => [397,469],'links' => ['http://example.com/projects/397/sites/399','http://example.com/projects/469/sites/399']},{'customLatitude' => nil,'customLongitude' => nil,'description' => nil,'id' => 401,'locationObfuscated' => true,'name' => 'Site 5','projectIds' => [397],'links' => ['http://example.com/projects/397/sites/401']},{'customLatitude' => nil,'customLongitude' => nil,'description' => nil,'id' => 398,'locationObfuscated' => true,'name' => 'Site 6','projectIds' => [397,469],'links' => ['http://example.com/projects/397/sites/398','http://example.com/projects/469/sites/398']}]}},'projection' => {'include' => ['id','siteId','durationSeconds','recordedDate']}}
      
      expect {
        create_filter(filter_params).query_full
      }.to raise_error(CustomErrors::FilterArgumentError, 'Array values cannot be hashes.')
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
                          }
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
                      }
                  },
                  not: {
                      duration_seconds: {
                          not_eq: 140
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
FROM\"audio_recordings\"WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
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
AND(((((((\"audio_recordings\".\"recorded_date\"ILIKE'%Hello%' \
OR\"audio_recordings\".\"media_type\"ILIKE'%world') \
OR\"audio_recordings\".\"duration_seconds\"=60) \
OR\"audio_recordings\".\"duration_seconds\"<=70) \
OR\"audio_recordings\".\"duration_seconds\"=50) \
OR\"audio_recordings\".\"duration_seconds\">=80) \
OR\"audio_recordings\".\"channels\"=1) \
OR\"audio_recordings\".\"channels\"<=8888) \
AND(NOT(\"audio_recordings\".\"duration_seconds\"!=140)) \
AND(\"audio_recordings\".\"media_type\"ILIKE'%testing\\_testing%' \
OR\"audio_recordings\".\"status\"ILIKE'%testing\\_testing%') \
AND(\"audio_recordings\".\"status\"='hello' \
AND\"audio_recordings\".\"channels\"=28) \
ORDERBY\"audio_recordings\".\"duration_seconds\"DESCLIMIT10OFFSET0"

      compare_filter_sql(complex_sample, complex_result)

      @permission = FactoryGirl.create(:write_permission)
      user = @permission.user
      user_id = user.id

      complex_result_2 =
          "SELECT\"audio_recordings\".\"recorded_date\",\"audio_recordings\".\"site_id\", \
\"audio_recordings\".\"duration_seconds\",\"audio_recordings\".\"media_type\" \
FROM\"audio_recordings\" \
INNERJOIN\"sites\"ON\"sites\".\"id\"=\"audio_recordings\".\"site_id\"AND(\"sites\".\"deleted_at\"ISNULL) \
INNERJOIN\"projects_sites\"ON\"projects_sites\".\"site_id\"=\"sites\".\"id\" \
INNERJOIN\"projects\"ON\"projects\".\"id\"=\"projects_sites\".\"project_id\"AND(\"projects\".\"deleted_at\"ISNULL) \
WHERE(\"audio_recordings\".\"deleted_at\"ISNULL) \
AND(\"projects\".\"id\"IN(SELECT\"projects\".\"id\"FROM\"projects\"WHERE(\"projects\".\"deleted_at\"ISNULL)AND\"projects\".\"creator_id\"=#{user_id}) \
OR\"projects\".\"id\"IN(SELECT\"permissions\".\"project_id\"FROM\"permissions\"WHERE\"permissions\".\"user_id\"=#{user_id}AND\"permissions\".\"level\"IN('reader','writer','owner'))) \
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
AND(((((((\"audio_recordings\".\"recorded_date\"ILIKE'%Hello%' \
OR\"audio_recordings\".\"media_type\"ILIKE'%world') \
OR\"audio_recordings\".\"duration_seconds\"=60) \
OR\"audio_recordings\".\"duration_seconds\"<=70) \
OR\"audio_recordings\".\"duration_seconds\"=50) \
OR\"audio_recordings\".\"duration_seconds\">=80) \
OR\"audio_recordings\".\"channels\"=1) \
OR\"audio_recordings\".\"channels\"<=8888) \
AND(NOT(\"audio_recordings\".\"duration_seconds\"!=140)) \
AND(\"audio_recordings\".\"media_type\"ILIKE'%testing\\_testing%' \
OR\"audio_recordings\".\"status\"ILIKE'%testing\\_testing%') \
AND(\"audio_recordings\".\"status\"='hello' \
AND\"audio_recordings\".\"channels\"=28) \
ORDERBY\"audio_recordings\".\"duration_seconds\"DESCLIMIT10OFFSET0"



      filter_query = Filter::Query.new(
          complex_sample,
          Access::Query.audio_recordings(user, Access::Core.levels_allow),
          AudioRecording,
          AudioRecording.filter_settings
      )

      expect(filter_query.query_full.to_sql.gsub(/\s+/, '')).to eq(complex_result_2.gsub(/\s+/, ''))

    end
  end
end
