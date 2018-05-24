

with cohort_comparison_ref as
(
  @comparisons
),
cte as
(
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
  	case when comparator.p90_value is not null then comparator.p90_value else 0 end as comparator_p90_value
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
      from cohort_comparison_ref ccr1,
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
      join cohort_comparison_ref ccr1
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
      join cohort_comparison_ref ccr1
      on cfd1.cohort_definition_id = ccr1.comparator_id
    ) comparator on cc1.comparison_id = comparator.comparison_id
        and cc1.covariate_id = comparator.covariate_id
  )
select distinct 
  CONCEPT_ID,
  COVARIATE_NAME,
  TARGET_AVG_VALUE as TARGET_STAT_VALUE,
  COMPARATOR_AVG_VALUE as COMPARATOR_STAT_VALUE,
  'Risk Scores' as DOMAIN_ID,
  TARGET_STDEV_VALUE,
  COMPARATOR_STDEV_VALUE
from cte
;