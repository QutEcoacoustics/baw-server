# frozen_string_literal: true

module Report
  class AudioEvents < Report::Cte::Node
    include Report::Cte::Dsl

    table_name 'audio_event_report'

    default_options do
      {
        bucket_size: 'day',
        start_time: nil,
        end_time: nil,
        scaling_factor: 1920,
        lower_field: :recorded_date,
        upper_field: :end_date
      }
    end

    depends_on do
      {
        accumulation: Report::Ctes::AggTagAccumulation,
        composition: Report::Ctes::EventComposition
      }
    end

    select do
      Arel::SelectManager.new.project(
        accumulation.project(Arel.star),
        composition.project(Arel.star)
      )
    end
  end
end
