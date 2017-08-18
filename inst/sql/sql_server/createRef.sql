IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_ref', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_ref

select A.cohort_id, A.cohort_name
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_ref
from
(
  @cohortDefinitionSqls	
) A
;
