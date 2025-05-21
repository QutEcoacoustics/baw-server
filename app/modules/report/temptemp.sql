SELECT tag_id, provenance_id,
audio_event_id, WIDTH_BUCKET(score,
score_minimum, score_maximum, 50 ) as bin_id,
(count(audio_event_id) OVER (partition by tag_id, provenance_id)) as group_count FROM source;

WITH bins AS (SELECT 
  tag_id, 
  provenance_id,
  audio_event_id, 
  WIDTH_BUCKET(score, score_minimum, score_maximum, 50 ) as bin_id,
  (count(audio_event_id) OVER (partition by tag_id, provenance_id)) as group_count
  FROM source
), bin_counts AS (
  SELECT
  tag_id, provenance_id,
  bin_id,
  count(bin_id) as bin_count,
  group_count
  from bins 
  group by tag_id, provenance_id, bin_id, group_count
), bin_fractions AS (
  SELECT
  tag_id, provenance_id,
  bin_id,
  (bin_count::float / group_count) as bin_fraction
  from bin_counts
)

SELECT
  series.bin_id AS series,
  bin_fractions.tag_id,
  bin_fractions.provenance_id,
  COALESCE(bin_fractions.bin_fraction, 0) AS bin_fraction
FROM bin_fractions
RIGHT OUTER JOIN (
  SELECT 
    dist_inct.tag_id,
    dist_inct.provenance_id,
    gs.bin_id
  FROM (
    SELECT DISTINCT tag_id, provenance_id 
    FROM bin_fractions
  ) dist_inct
  CROSS JOIN generate_series(1, 50) AS gs(bin_id)
) series
  ON bin_fractions.tag_id = series.tag_id
  AND bin_fractions.provenance_id = series.provenance_id
  AND bin_fractions.bin_id = series.bin_id
ORDER BY series.tag_id, series.provenance_id, series.bin_id;


-- cross join with generate series 1 to 50 
SELECT
  series,
  bin_fractions.tag_id, bin_fractions.provenance_id,
  bin_fractions.bin_id,
  bin_fractions.bin_fraction
FROM bin_fractions
RIGHT OUTER JOIN (select values FROM (SELECT DISTINCT tag_id, provenance_id FROM bin_fractions) dist_inct cross join generate_series(1, 50) as values) AS series 
ON series = bin_fractions.bin_id
ORDER BY tag_id, provenance_id, series;
