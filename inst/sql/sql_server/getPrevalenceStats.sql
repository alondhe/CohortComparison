
with target
as
(
  select distinct 
    A.CONCEPT_ID,
    A.COVARIATE_NAME,
    A.AVG_VALUE as TARGET_STAT_VALUE,
    B.DOMAIN_ID
  FROM @resultsDatabaseSchema.cc_results A
  join @vocabDatabaseSchema.concept B on A.concept_id = B.concept_id
  where A.cc_generation_id = @generationId and [type] = 'PREVALENCE'
    and A.cohort_definition_id = @targetCohortId
),
comparator as
(
  select distinct 
    A.CONCEPT_ID,
    A.COVARIATE_NAME,
    A.AVG_VALUE as COMPARATOR_STAT_VALUE,
    B.DOMAIN_ID
  FROM @resultsDatabaseSchema.cc_results A
  join @vocabDatabaseSchema.concept B on A.concept_id = B.concept_id
  where A.cc_generation_id = @generationId and [type] = 'PREVALENCE'
    and A.cohort_definition_id = @comparatorCohortId
)
select 
  T.CONCEPT_ID,
  T.COVARIATE_NAME,
  T.TARGET_STAT_VALUE,
  C.COMPARATOR_STAT_VALUE,
  T.DOMAIN_ID
from target T
join comparator C on T.CONCEPT_ID = C.CONCEPT_ID
;