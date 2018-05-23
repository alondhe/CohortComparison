/*with cte
as
(
  @comparisons
)
select *
into #cohort_comparison_ref
from cte;

IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_cohort_comparison_summary', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_cohort_comparison_summary;
*/

with cohort_comparison_ref as
(
  @comparisons
),
cte as
(
  select 
    cc1.comparison_id, 
    cc1.covariate_id,
    cc1.covariate_name,
    cc1.analysis_id, 
    cc1.concept_id,
  	cc1.domain_id,
  	cc1.analysis_name,
  	cc1.time_window,
  	target_cohort.cohort_definition_id as target_cohort_definition_id,
  	case when target_cohort.stat_value is not null then target_cohort.stat_value else 0 end as target_stat_value,
  	comparator.cohort_definition_id as comparator_cohort_definition_id,
  	case when comparator.stat_value is not null then comparator.stat_value else 0 end as comparator_stat_value
--  	abs(case when (target_cohort.stat_value is not null and target_cohort.stat_value < 1) 
--  	  and (comparator.stat_value is not null and comparator.stat_value < 1)
--  		then (target_cohort.stat_value - comparator.stat_value) / sqrt((target_cohort.stat_value*(1-target_cohort.stat_value) + 
--  		  comparator.stat_value*(1-comparator.stat_value))/2) else 0 end) as abs_standard_diff
  
  FROM
  (
    select
      ccr1.comparison_id,
      cfar1.covariate_id,
      cfar1.covariate_name,
      cfar1.analysis_id,
      cfar1.concept_id,
      cfar2.domain_id,
      cfar2.analysis_name,
      coalesce(cfar2.end_day - cfar2.start_day, 0) as time_window
    from
    cohort_comparison_ref ccr1,
    (
      select cfr0.*
  	  from @resultsDatabaseSchema.cohort_features_ref cfr0
  	  inner join
  	  (
  	    select distinct covariate_id
  	    from @resultsDatabaseSchema.cohort_features_ref
  	    where cohort_definition_id in (select distinct target_id as cohort_definition_id from cohort_comparison_ref union select distinct comparator_id as cohort_definition_id from cohort_comparison_ref)
  	  ) cf0
  	  on cfr0.covariate_id = cf0.covariate_id
  	  where cfr0.cohort_definition_id in (select distinct target_id as cohort_definition_id from cohort_comparison_ref union select distinct comparator_id as cohort_definition_id from cohort_comparison_ref)
    ) cfar1
      join @resultsDatabaseSchema.cohort_features_analysis_ref cfar2
      on cfar1.analysis_id = cfar2.analysis_id
  ) cc1
  
  inner join
  (
    select
      ccr1.comparison_id,
      ccr1.target_id as cohort_definition_id,
      csr1.covariate_id,
      csr1.sum_value as count_value,
      csr1.average_value as stat_value
    from @resultsDatabaseSchema.cohort_features csr1
    inner join cohort_comparison_ref ccr1
      on csr1.cohort_definition_id = ccr1.target_id
    ) target_cohort
  on cc1.comparison_id = target_cohort.comparison_id
    and cc1.covariate_id = target_cohort.covariate_id
  
  inner join
  (
    select
      ccr1.comparison_id,
      ccr1.comparator_id as cohort_definition_id,
      csr1.covariate_id,
      csr1.sum_value as count_value,
      csr1.average_value as stat_value
    from @resultsDatabaseSchema.cohort_features csr1
    inner join cohort_comparison_ref ccr1
      on csr1.cohort_definition_id = ccr1.comparator_id
  ) comparator
  on cc1.comparison_id = comparator.comparison_id
  and cc1.covariate_id = comparator.covariate_id
)
select distinct 
  A.CONCEPT_ID,
  A.COVARIATE_NAME,
  A.COMPARATOR_STAT_VALUE,
  A.TARGET_STAT_VALUE,
  B.DOMAIN_ID
--  case 
--    when A.ABS_STANDARD_DIFF < 0.1 then 'Balanced'
--    else B.DOMAIN_ID
--  end as DOMAIN_ID,
--  round(A.ABS_STANDARD_DIFF, 3) as ABS_STANDARD_DIFF
from cte A
join @cdmDatabaseSchema.concept B on A.concept_id = B.concept_id
--where target_cohort_definition_id = @targetId and comparator_cohort_definition_id = @comparatorId
;

/*

IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_cohort_comparison_summary_dist', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_cohort_comparison_summary_dist;

--HINT DISTRIBUTE_ON_KEY(comparison_id)
select cc1.comparison_id, cc1.covariate_id, cc1.covariate_name, cc1.analysis_id, cc1.concept_id,
	cc1.domain_id, cc1.analysis_name, cc1.time_window,
	
	target_cohort.cohort_definition_id as target_cohort_definition_id,
	case when target_cohort.count_value is not null then target_cohort.count_value else 0 end as target_count_value,
	case when target_cohort.average_value is not null then target_cohort.average_value else 0 end as target_avg_value,
	case when target_cohort.standard_deviation is not null then target_cohort.standard_deviation else 0 end as target_stdev_value,
	case when target_cohort.median_value is not null then target_cohort.median_value else 0 end as target_median_value,
	case when target_cohort.p10_value is not null then target_cohort.p10_value else 0 end as target_p10_value,
	case when target_cohort.p25_value is not null then target_cohort.p25_value else 0 end as target_p25_value,
	case when target_cohort.p75_value is not null then target_cohort.p75_value else 0 end as target_p75_value,
	case when target_cohort.p90_value is not null then target_cohort.p90_value else 0 end as target_p90_value,
	
	comparator.cohort_definition_id as comparator_cohort_definition_id,
	case when comparator.count_value is not null then comparator.count_value else 0 end as comparator_count_value,
	case when comparator.average_value is not null then comparator.average_value else 0 end as comparator_avg_value,
	case when comparator.standard_deviation is not null then comparator.standard_deviation else 0 end as comparator_stdev_value,
	case when comparator.median_value is not null then comparator.median_value else 0 end as comparator_median_value,
	case when comparator.p10_value is not null then comparator.p10_value else 0 end as comparator_p10_value,
	case when comparator.p25_value is not null then comparator.p25_value else 0 end as comparator_p25_value,
	case when comparator.p75_value is not null then comparator.p75_value else 0 end as comparator_p75_value,
	case when comparator.p90_value is not null then comparator.p90_value else 0 end as comparator_p90_value,
	case when target_cohort.standard_deviation + comparator.standard_deviation > 0
		then (target_cohort.average_value - comparator.average_value) / sqrt((target_cohort.standard_deviation + comparator.standard_deviation)/2) else 0 end as standard_diff,
	abs(case when target_cohort.standard_deviation + comparator.standard_deviation > 0
		then (target_cohort.average_value - comparator.average_value) / sqrt((target_cohort.standard_deviation + comparator.standard_deviation)/2) else 0 end) as abs_standard_diff,
	case when target_cohort.average_value is not null and comparator.average_value is not null and comparator.average_value <> 0
		then target_cohort.average_value / comparator.average_value else 1 end as relative_risk
into @scratchDatabaseSchema.@tablePrefix_cohort_comparison_summary_dist
from
(
  select
    ccr1.comparison_id,
    cf1.covariate_id,
    cf1.covariate_name,
    cf1.analysis_id,
    cf1.concept_id,
    cfar1.domain_id,
    cfar1.analysis_name,
    coalesce(cfar1.end_day - cfar1.start_day, 0) as time_window
  from #cohort_comparison_ref ccr1,
  (
    select cfar0.*
	  from @resultsDatabaseSchema.cohort_features_ref cfar0
	  inner join
	  (
	    select distinct covariate_id from @resultsDatabaseSchema.cohort_features_dist
	  ) c1 on cfar0.covariate_id = c1.covariate_id
  ) cf1
  join @resultsDatabaseSchema.cohort_features_analysis_ref cfar1
    on cfar1.analysis_id = cf1.analysis_id
) cc1

join
(
  select 
    ccr1.comparison_id, 
    ccr1.target_id as cohort_definition_id, 
    cfd1.covariate_id, 
    cfd1.count_value, 
    cfd1.average_value, 
    cfd1.standard_deviation, 
    cfd1.median_value, 
    cfd1.p10_value, 
    cfd1.p25_value, 
    cfd1.p75_value, 
    cfd1.p90_value
  from @resultsDatabaseSchema.cohort_features_dist cfd1
  join #cohort_comparison_ref ccr1
    on cfd1.cohort_definition_id = ccr1.target_id
) target_cohort on cc1.comparison_id = target_cohort.comparison_id
  and cc1.covariate_id = target_cohort.covariate_id

join
(
  select 
    ccr1.comparison_id, 
    ccr1.comparator_id as cohort_definition_id, 
    cfd1.covariate_id, 
    cfd1.count_value, 
    cfd1.average_value, 
    cfd1.standard_deviation, 
    cfd1.median_value, 
    cfd1.p10_value, 
    cfd1.p25_value, 
    cfd1.p75_value, 
    cfd1.p90_value
  from @resultsDatabaseSchema.cohort_features_dist cfd1
  join #cohort_comparison_ref ccr1
  on cfd1.cohort_definition_id = ccr1.comparator_id
) comparator on cc1.comparison_id = comparator.comparison_id
    and cc1.covariate_id = comparator.covariate_id
;
*/
/*
truncate table #cohort_comparison_ref;
drop table #cohort_comparison_ref;/*
