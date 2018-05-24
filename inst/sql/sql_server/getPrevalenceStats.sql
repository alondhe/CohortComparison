

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
  A.TARGET_STAT_VALUE,
  A.COMPARATOR_STAT_VALUE,
  B.DOMAIN_ID,
  null as TARGET_STDEV_VALUE,
  null as COMPARATOR_STDEV_VALUE

from cte A
join @cdmDatabaseSchema.concept B on A.concept_id = B.concept_id
;

