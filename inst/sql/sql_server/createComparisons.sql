IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparisons', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparisons;

select A.comparison_id, A.target_id, A.comparator_id
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparisons
from
(
	@cohortComparisonSqls
) A
;