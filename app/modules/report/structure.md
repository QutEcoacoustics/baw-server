# structure ideas

- functions as data
- functional data modelling and algerbraic data types
- declarative encoding - provide a 'description' of the solution, and later
  interpret it to provide the solution 
- interpreter design pattern 

Facts

1. All reports have a base query, provided by the filter. It includes
   permissions filtering. 
2. Reports need a base table. The base table is the main source of data for the
   report. The base table is the product of applying additional joins and
   projections to the base query.
   1. Note: It might have been better to join verifications to the base query, 
      instead of creating a base_verifications table. 
3. Report joins are called dimensions. Dimensions are used throughout the
   queries as part of projections, grouping, filtering, etc. 
4. Reports can be declared based on their final output fields.
5. Reports can have complex output fields. How to encode this?

Accumulation series aggregate:

`accumulation_series_aggregate.as('accumulation_series')`
implementation hidden, nothing reusable or composable. 

```rb
accumulation_series_ctes, accumulation_series_aggregate = TimeSeries::Accumulation.accumulation_series_result(
  base_table, @parameters
)
```

- I want the accumulation series projection, and the ctes (to include in the
  with clause). 
- You wil need the base_table to do this (source data).
- You will need the request parameters to do this (for the time series setup -
  report start, end etc). 
