select 
  A.CONCEPT_ID,
  A.COVARIATE_NAME,
  A.COMPARATOR_STAT_VALUE,
  A.TARGET_STAT_VALUE,
  B.DOMAIN_ID,
  round(A.ABS_STANDARD_DIFF, 3) as ABS_STANDARD_DIFF
from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary A
join @cdmDatabaseSchema.concept B on A.concept_id = B.concept_id
where target_cohort_definition_id = @targetId and comparator_cohort_definition_id = @comparatorId
;
