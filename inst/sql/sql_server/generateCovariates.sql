IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref;

select 
  cc1.comparison_id, cc1.target_id, cr1.cohort_name as target_name, 
  cc1.comparator_id, cr2.cohort_name as comparator_name
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref
from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparisons cc1
inner join @scratchDatabaseSchema.@tablePrefix_LAB_cohort_ref cr1
  on cc1.target_id = cr1.cohort_id
inner join @scratchDatabaseSchema.@tablePrefix_LAB_cohort_ref  cr2
	on cc1.comparator_id = cr2.cohort_id
;

--1. build all cohorts

IF OBJECT_ID('tempdb..#cohort', 'U') IS NOT NULL
	drop table #cohort;


--all cohorts

select 
  subject_id as person_id, cohort_definition_id, cohort_start_date, cohort_end_date
into #cohort
from @cdmDatabaseSchema.cohort
where cohort_definition_id in 
(select cohort_id from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_ref)
;



--2. generate cohort characterization
--use covariates from FeatureExtraction
IF OBJECT_ID('tempdb..#cohort_summary_analysis_ref', 'U') IS NOT NULL
	drop table #cohort_summary_analysis_ref;

create table #cohort_summary_analysis_ref
(	covariate_id BIGINT,
	covariate_name VARCHAR(1000),
	analysis_id INT,
	analysis_name VARCHAR(1000),
	domain_id VARCHAR(100),
	time_window VARCHAR(100),
	concept_id INT
)
;



IF OBJECT_ID('tempdb..#cohort_summary_results', 'U') IS NOT NULL
	drop table #cohort_summary_results;

create table #cohort_summary_results
(	cohort_definition_id BIGINT,
	covariate_id BIGINT,
	count_value BIGINT,
	stat_value FLOAT
)
;

IF OBJECT_ID('tempdb..#cohort_summary_results_dist', 'U') IS NOT NULL
	drop table #cohort_summary_results_dist;

create table #cohort_summary_results_dist
(	cohort_definition_id BIGINT,
	covariate_id BIGINT,
	count_value FLOAT,
	min_value FLOAT,
	max_value FLOAT,
	avg_value FLOAT,
	stdev_value FLOAT,
	median_value FLOAT,
	p10_value FLOAT,
	p25_value FLOAT,
	p75_value FLOAT,
	p90_value FLOAT
)
;



--count number of persons in each cohort
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	values (0, 'number of distinct persons', 0, 'Person count', 'Person', NULL, 0)
; 

INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT cohort_definition_id,
	0 as covariate_id,
	count(distinct cc1.person_id) as count_value,
	1 as stat_value
from #cohort cc1
group by cohort_definition_id 
;



/**************************
***************************
DEMOGRAPHICS
***************************
**************************/

--number persons by gender
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	SELECT concept_id, 'Persons by gender: gender = ' + concept_name, 1, 'Persons by gender', 'Gender', NULL, concept_id
		FROM @cdmDatabaseSchema.concept
		WHERE LOWER(concept_class_id) = 'gender'
		AND standard_concept = 'S'
;

INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	p1.gender_concept_id AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER JOIN @cdmDatabaseSchema.person p1
	ON cc1.person_id = p1.person_id
WHERE p1.gender_concept_id IN (
		SELECT concept_id
		from @cdmDatabaseSchema.concept
		WHERE LOWER(concept_class_id) = 'gender'
		AND standard_concept = 'S'
		)
GROUP BY cc1.cohort_definition_id, p1.gender_concept_id
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




--number persons by race
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	SELECT concept_id, 'Persons by race: race = ' + concept_name, 2, 'Persons by race', 'Race', NULL, concept_id
		from @cdmDatabaseSchema.concept
		WHERE LOWER(concept_class_id) = 'race'
		AND standard_concept = 'S'
;

INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	p1.race_concept_id AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER JOIN @cdmDatabaseSchema.person p1
	ON cc1.person_id = p1.person_id
WHERE p1.race_concept_id IN (
		SELECT concept_id
		from @cdmDatabaseSchema.concept
		WHERE LOWER(concept_class_id) = 'race'
		AND standard_concept = 'S'
		)
GROUP BY cc1.cohort_definition_id, p1.race_concept_id
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;



--number persons by ethnicity
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	SELECT concept_id, 'Persons by ethnicity: ethnicity = ' + concept_name, 3, 'Persons by ethnicity', 'Ethnicity', NULL, concept_id
		from @cdmDatabaseSchema.concept
		WHERE LOWER(concept_class_id) = 'ethnicity'
		AND standard_concept = 'S'
;

INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	p1.ethnicity_concept_id AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER JOIN @cdmDatabaseSchema.person p1
	ON cc1.person_id = p1.person_id
WHERE p1.ethnicity_concept_id IN (
		SELECT concept_id
		from @cdmDatabaseSchema.concept
		WHERE LOWER(concept_class_id) = 'ethnicity'
		AND standard_concept = 'S'
		)
GROUP BY cc1.cohort_definition_id, p1.ethnicity_concept_id
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;


--age
--count by 5yr buckets
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT FLOOR((YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) / 5) + 10 AS covariate_id,
	'Age group: ' + CAST((FLOOR((YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) / 5) )*5 AS VARCHAR) + '-' + CAST((FLOOR((YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) / 5) +1)*5-1 AS VARCHAR)  AS covariate_name,
	4 AS analysis_id,
	'Age group','Person',NULL,
	0 AS concept_id
FROM #cohort cc1
INNER JOIN @cdmDatabaseSchema.person p1
	ON cc1.person_id = p1.person_id
WHERE (YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) >= 0
	AND (YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) < 100
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	FLOOR((YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) / 5) + 10 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER JOIN @cdmDatabaseSchema.person p1
	ON cc1.person_id = p1.person_id
WHERE (YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) >= 0
	AND (YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) < 100
GROUP BY cc1.cohort_definition_id, FLOOR((YEAR(cc1.cohort_start_date) - p1.YEAR_OF_BIRTH) / 5) + 10
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;


--distribution of age values
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	values (-1, 'distribution of age at cohort start', 4, 'Age distribution', 'Person', NULL, 0)
; 


with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, YEAR(cc1.cohort_start_date) - p1.year_of_birth as stat_value
	FROM #cohort cc1
	INNER JOIN @cdmDatabaseSchema.person p1
	ON cc1.person_id = p1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	-1 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults 
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;




--index year
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT YEAR(cc1.cohort_start_date) AS covariate_id,
	'Index year: ' + CAST(YEAR(cc1.cohort_start_date) AS VARCHAR)  AS covariate_name,
	5 AS analysis_id,
	'Index year', 'Person', NULL,
	0 AS concept_id
FROM #cohort cc1
;


--note, if one person has multiple records in a cohort, then they could get counted in multiple years, so sum(year) won't add up to total
INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	YEAR(cc1.cohort_start_date) AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
GROUP BY cc1.cohort_definition_id, YEAR(cc1.cohort_start_date)
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




--index month
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT MONTH(cc1.cohort_start_date) + 40 AS covariate_id,
	'Index month: ' + CAST(MONTH(cc1.cohort_start_date) AS VARCHAR)  AS covariate_name,
	6 AS analysis_id,
	'Index month', 'Person', NULL,
	0 AS concept_id
FROM #cohort cc1
;


--note, if one person has multiple records in a cohort, then they could get counted in multiple months, so sum(month) won't add up to total
INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	MONTH(cc1.cohort_start_date) + 40 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
GROUP BY cc1.cohort_definition_id, MONTH(cc1.cohort_start_date)
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;





/**************************
***************************
OBSERVATION TIME
***************************
**************************/

--observation period prior to index (observation period start -> cohort start)

--continous distribution
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	values (-90, 'Observation time prior to cohort start', 90, 'Observation time prior to cohort start', 'Observation period', NULL, 0)
; 


with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, 
		DATEDIFF(dd,op1.observation_period_start_date,cc1.cohort_start_date) AS stat_value
	FROM #cohort cc1
	inner join @cdmDatabaseSchema.observation_period op1
	on cc1.person_id = op1.person_id
	and cc1.cohort_start_date >= op1.observation_period_start_date
	and cc1.cohort_start_date <= op1.observation_period_end_date
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	90 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;


--discrete 30d intervals
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT FLOOR(DATEDIFF(dd,op1.observation_period_start_date,cc1.cohort_start_date)/30)*1000 + 90 AS covariate_id,
	'Observation time prior to cohort start: ' + CAST(FLOOR(DATEDIFF(dd,op1.observation_period_start_date,cc1.cohort_start_date)/30)*30 AS VARCHAR) + ' - ' + CAST((FLOOR(DATEDIFF(dd,op1.observation_period_start_date,cc1.cohort_start_date)/30)+1)*30-1 AS VARCHAR) AS covariate_name,
	90 AS analysis_id,
	'Observation time prior to cohort start', 'Observation period', NULL,
	0 AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.observation_period op1
on cc1.person_id = op1.person_id
and cc1.cohort_start_date >= op1.observation_period_start_date
and cc1.cohort_start_date <= op1.observation_period_end_date
;


INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	FLOOR(DATEDIFF(dd,op1.observation_period_start_date,cc1.cohort_start_date)/30)*1000 + 90 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER JOIN @cdmDatabaseSchema.observation_period op1
on cc1.person_id = op1.person_id
and cc1.cohort_start_date >= op1.observation_period_start_date
and cc1.cohort_start_date <= op1.observation_period_end_date
GROUP BY cc1.cohort_definition_id, FLOOR(DATEDIFF(dd,op1.observation_period_start_date,cc1.cohort_start_date)/30)*1000 + 90
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




--observation period after index (cohort start -> observation period end)

--continous distribution
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	values (-91, 'Observation time after cohort start', 91, 'Observation time after cohort start', 'Observation period', NULL, 0)
; 

with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, 
		DATEDIFF(dd,cc1.cohort_start_date,op1.observation_period_end_date) AS stat_value
	FROM #cohort cc1
	inner join @cdmDatabaseSchema.observation_period op1
	on cc1.person_id = op1.person_id
	and cc1.cohort_start_date >= op1.observation_period_start_date
	and cc1.cohort_start_date <= op1.observation_period_end_date
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	91 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;


--discrete 30d intervals
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT FLOOR(DATEDIFF(dd,cc1.cohort_start_date,op1.observation_period_end_date)/30)*1000 + 91 AS covariate_id,
	'Observation time after cohort start: ' + CAST(FLOOR(DATEDIFF(dd,cc1.cohort_start_date,op1.observation_period_end_date)/30)*30 AS VARCHAR) + ' - ' + CAST((FLOOR(DATEDIFF(dd,cc1.cohort_start_date,op1.observation_period_end_date)/30)+1)*30-1 AS VARCHAR) AS covariate_name,
	91 AS analysis_id,
	'Observation time after cohort start', 'Observation period', NULL,
	0 AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.observation_period op1
on cc1.person_id = op1.person_id
and cc1.cohort_start_date >= op1.observation_period_start_date
and cc1.cohort_start_date <= op1.observation_period_end_date
;


INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	FLOOR(DATEDIFF(dd,cc1.cohort_start_date,op1.observation_period_end_date)/30)*1000 + 91 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
inner join @cdmDatabaseSchema.observation_period op1
on cc1.person_id = op1.person_id
and cc1.cohort_start_date >= op1.observation_period_start_date
and cc1.cohort_start_date <= op1.observation_period_end_date
GROUP BY cc1.cohort_definition_id, FLOOR(DATEDIFF(dd,cc1.cohort_start_date,op1.observation_period_end_date)/30)*1000 + 91
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;





--observation time during cohort time (cohort start -> cohort end)


--continuous distribution
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
	values (-92, 'Cohort time after cohort start', 92, 'Cohort time after cohort start', 'Observation period', NULL, 0)
; 


with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, 
		DATEDIFF(dd,cc1.cohort_start_date,cc1.cohort_end_date) AS stat_value
	FROM #cohort cc1
	inner join @cdmDatabaseSchema.observation_period op1
	on cc1.person_id = op1.person_id
	and cc1.cohort_start_date >= op1.observation_period_start_date
	and cc1.cohort_start_date <= op1.observation_period_end_date
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	92 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;


--discrete 30d intervals
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT FLOOR(DATEDIFF(dd,cc1.cohort_start_date,cc1.cohort_end_date)/30)*1000 + 92 AS covariate_id,
	'Cohort time after cohort start: ' + CAST(FLOOR(DATEDIFF(dd,cc1.cohort_start_date,cc1.cohort_end_date)/30)*30 AS VARCHAR) + ' - ' + CAST((FLOOR(DATEDIFF(dd,cc1.cohort_start_date,cc1.cohort_end_date)/30)+1)*30-1 AS VARCHAR) AS covariate_name,
	92 AS analysis_id,
	'Cohort time after cohort start', 'Observation period', NULL,
	0 AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.observation_period op1
on cc1.person_id = op1.person_id
and cc1.cohort_start_date >= op1.observation_period_start_date
and cc1.cohort_start_date <= op1.observation_period_end_date
;


INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	FLOOR(DATEDIFF(dd,cc1.cohort_start_date,cc1.cohort_end_date)/30)*1000 + 92 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
inner join @cdmDatabaseSchema.observation_period op1
on cc1.person_id = op1.person_id
and cc1.cohort_start_date >= op1.observation_period_start_date
and cc1.cohort_start_date <= op1.observation_period_end_date
GROUP BY cc1.cohort_definition_id, FLOOR(DATEDIFF(dd,cc1.cohort_start_date,cc1.cohort_end_date)/30)*1000 + 92
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




/**************************
***************************
CONDITION OCCURRENCE
***************************
**************************/

IF OBJECT_ID('tempdb..#concept_ancestor_grouping', 'U') IS NOT NULL
	drop table #concept_ancestor_grouping;

--create a temp table of concepts to aggregate to:
select ca1.ancestor_concept_id, ca1.descendant_concept_id
into #concept_ancestor_grouping
from @cdmDatabaseSchema.concept_ancestor ca1
inner join
(
  select c1.concept_id, c1.concept_name, c1.vocabulary_id, c1.domain_id
  from @cdmDatabaseSchema.concept c1
  inner join @cdmDatabaseSchema.concept_ancestor ca1
  on ca1.ancestor_concept_id = 441840 /* clinical finding */
  and c1.concept_id = ca1.descendant_concept_id
  where c1.concept_name not like '%finding'
  and c1.concept_name not like 'disorder of%'
  and c1.concept_name not like 'finding of%'
  and c1.concept_name not like 'finding related to%'
  and c1.concept_name not like 'disease of%'
  and c1.concept_name not like 'injury of%'
  and c1.concept_name not like '%by site'
  and c1.concept_name not like '%by body site'
  and c1.concept_name not like '%by mechanism'
  and c1.concept_name not like '%of body region'
  and c1.concept_name not like '%of anatomical site'
  and c1.concept_name not like '%of specific body structure%'
  and c1.concept_name not in ('Disease','Clinical history and observation findings','General finding of soft tissue','Traumatic AND/OR non-traumatic injury','Drug-related disorder',
  	'Traumatic injury', 'Mass of body structure','Soft tissue lesion','Neoplasm and/or hamartoma','Inflammatory disorder','Congenital disease','Inflammation of specific body systems','Disorder due to infection',
  	'Musculoskeletal and connective tissue disorder','Inflammation of specific body organs','Complication','Finding by method','General finding of observation of patient',
  	'O/E - specified examination findings','Skin or mucosa lesion','Skin lesion',	'Complication of procedure', 'Mass of trunk','Mass in head or neck', 'Mass of soft tissue','Bone injury','Head and neck injury',
  	'Acute disease','Chronic disease', 'Lesion of skin and/or skin-associated mucous membrane')
  and c1.domain_id = 'Condition'
) t1
on ca1.ancestor_concept_id = t1.concept_id
;





----conditions exist:  episode in last 365d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition occurrence record for the verbatim concept observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	101 AS analysis_id,
--	'Condition occurrence record for the verbatim concept observed during 365d on or prior to cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'365d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(co1.condition_concept_id AS BIGINT) * 1000 + 101 AS covariate_id,
--	co1.condition_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(co1.condition_concept_id AS BIGINT) * 1000 + 101 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(co1.condition_concept_id AS BIGINT) * 1000 + 101
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--using aggregate concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Condition occurrence record for the concept or any its descendants observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	111 AS analysis_id,
	'Condition occurrence record for the concept or any its descendants observed during 365d on or prior to cohort index' AS analysis_name,
	'Condition' AS domain_id,
	'365d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 111 AS covariate_id,
	cag1.ancestor_concept_id AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.condition_occurrence co1
	ON cc1.person_id = co1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON co1.condition_concept_id = cag1.descendant_concept_id
WHERE co1.condition_concept_id > 0
	AND co1.condition_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
) t1
LEFT JOIN @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 111 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
inner join @cdmDatabaseSchema.condition_occurrence co1
	ON cc1.person_id = co1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON co1.condition_concept_id = cag1.descendant_concept_id
WHERE co1.condition_concept_id > 0
	AND co1.condition_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 111
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




----conditions exist:  episode in last 30d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition occurrence record for the verbatim concept observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	102 AS analysis_id,
--	'Condition occurrence record for the verbatim concept observed during 30d on or prior to cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(co1.condition_concept_id AS BIGINT) * 1000 + 102 AS covariate_id,
--	co1.condition_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(co1.condition_concept_id AS BIGINT) * 1000 + 102 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(co1.condition_concept_id AS BIGINT) * 1000 + 102
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--using aggregate concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Condition occurrence record for the concept or any its descendants observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	112 AS analysis_id,
	'Condition occurrence record for the concept or any its descendants observed during 30d on or prior to cohort index' AS analysis_name,
	'Condition' AS domain_id,
	'30d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 112 AS covariate_id,
	cag1.ancestor_concept_id AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.condition_occurrence co1
	ON cc1.person_id = co1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON co1.condition_concept_id = cag1.descendant_concept_id
WHERE co1.condition_concept_id > 0
	AND co1.condition_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 112 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
inner join @cdmDatabaseSchema.condition_occurrence co1
	ON cc1.person_id = co1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON co1.condition_concept_id = cag1.descendant_concept_id
WHERE co1.condition_concept_id > 0
	AND co1.condition_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 112
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




----conditions exist:  episode as primary inpatient diagnosis in last 180d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition occurrence record for the verbatim concept observed as primary inpatient diagnosis during 180d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	103 AS analysis_id,
--	'Condition occurrence record for the verbatim concept observed as primary inpatient diagnosis during 180d on or prior to cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'180d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(co1.condition_concept_id AS BIGINT) * 1000 + 103 AS covariate_id,
--	co1.condition_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_type_concept_id IN (38000183, 38000184, 38000199, 38000200)
--	AND co1.condition_start_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(co1.condition_concept_id AS BIGINT) * 1000 + 103 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_type_concept_id IN (38000183, 38000184, 38000199, 38000200)
--	AND co1.condition_start_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(co1.condition_concept_id AS BIGINT) * 1000 + 103
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition occurrence record for the concept or any its descendants observed as primary inpatient diagnosis during 180d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	113 AS analysis_id,
--	'Condition occurrence record for the concept or any its descendants observed as primary inpatient diagnosis during 180d on or prior to cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'180d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 113 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON co1.condition_concept_id = cag1.descendant_concept_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_type_concept_id IN (38000183, 38000184, 38000199, 38000200)
--	AND co1.condition_start_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 113 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.condition_occurrence co1
--	ON cc1.person_id = co1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON co1.condition_concept_id = cag1.descendant_concept_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_type_concept_id IN (38000183, 38000184, 38000199, 38000200)
--	AND co1.condition_start_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 113
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;



/**************************
***************************
CONDITION ERA
***************************
**************************/


--any time prior

----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition era record for the verbatim concept observed anytime on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	201 AS analysis_id,
--	'Condition era record for the verbatim concept observed anytime on or prior to cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'Anytime on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(co1.condition_concept_id AS BIGINT) * 1000 + 201 AS covariate_id,
--	co1.condition_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.condition_era co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_era_start_date <= cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(co1.condition_concept_id AS BIGINT) * 1000 + 201 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.condition_era co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_era_start_date <= cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(co1.condition_concept_id AS BIGINT) * 1000 + 201
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--using aggregate concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Condition era record for the concept or any its descendants observed during anytime on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	211 AS analysis_id,
	'Condition era record for the concept or any its descendants observed during anytime on or prior to cohort index' AS analysis_name,
	'Condition' AS domain_id,
	'Anytime on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 211 AS covariate_id,
	cag1.ancestor_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.condition_era co1
	ON cc1.person_id = co1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON co1.condition_concept_id = cag1.descendant_concept_id
WHERE co1.condition_concept_id > 0
	AND co1.condition_era_start_date <= cc1.cohort_start_date
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 211 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER join @cdmDatabaseSchema.condition_era co1
	ON cc1.person_id = co1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON co1.condition_concept_id = cag1.descendant_concept_id
WHERE co1.condition_concept_id > 0
	AND co1.condition_era_start_date <= cc1.cohort_start_date
GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 211
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;





----concurrent with index

----verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition era record for the verbatim concept observed concurrent (overlapping) with cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	202 AS analysis_id,
--	'Condition era record for the verbatim concept observed concurrent (overlapping) with cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'concurrent (overlapping) with cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(co1.condition_concept_id AS BIGINT) * 1000 + 202 AS covariate_id,
--	co1.condition_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.condition_era co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_era_start_date <= cc1.cohort_start_date
--	AND co1.condition_era_end_date >= cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(co1.condition_concept_id AS BIGINT) * 1000 + 202 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.condition_era co1
--	ON cc1.person_id = co1.person_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_era_start_date <= cc1.cohort_start_date
--	AND co1.condition_era_end_date >= cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(co1.condition_concept_id AS BIGINT) * 1000 + 202
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Condition era record for the concept or any its descendants observed concurrent (overlapping) with cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	211 AS analysis_id,
--	'Condition era record for the concept or any its descendants observed concurrent (overlapping) with cohort index' AS analysis_name,
--	'Condition' AS domain_id,
--	'concurrent (overlapping) with cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 212 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.condition_era co1
--	ON cc1.person_id = co1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON co1.condition_concept_id = cag1.descendant_concept_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_era_start_date <= cc1.cohort_start_date
--	AND co1.condition_era_end_date >= cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 212 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.condition_era co1
--	ON cc1.person_id = co1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON co1.condition_concept_id = cag1.descendant_concept_id
--WHERE co1.condition_concept_id > 0
--	AND co1.condition_era_start_date <= cc1.cohort_start_date
--	AND co1.condition_era_end_date >= cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 212
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




/**************************
***************************
DRUG EXPOSURE
***************************
**************************/


IF OBJECT_ID('tempdb..#concept_ancestor_grouping', 'U') IS NOT NULL
	drop table #concept_ancestor_grouping;


select ca1.ancestor_concept_id, ca1.descendant_concept_id
into #concept_ancestor_grouping
from @cdmDatabaseSchema.concept_ancestor ca1
inner join
(
	select concept_id
	from @cdmDatabaseSchema.concept
	where (vocabulary_id = 'ATC' and len(concept_code) in (3, 4, 5) )
		OR (vocabulary_id = 'RxNorm' and concept_class_id in ('Ingredient') )
) t1
on ca1.ancestor_concept_id = t1.concept_id
;


--drug exist:  episode in last 365d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug exposure record for the verbatim concept observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	401 AS analysis_id,
--	'Drug exposure record for the verbatim concept observed during 365d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'365d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(de1.drug_concept_id AS BIGINT) * 1000 + 401 AS covariate_id,
--	de1.drug_concept_id AS concept_id
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(de1.drug_concept_id AS BIGINT) * 1000 + 401 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(de1.drug_concept_id AS BIGINT) * 1000 + 401
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug exposure record for the concept or any its descendants observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	411 AS analysis_id,
--	'Drug exposure record for the concept or any its descendants observed during 365d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'365d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 411 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 411 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 411
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;





----drug exist:  episode in last 30d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug exposure record for the verbatim concept observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	402 AS analysis_id,
--	'Drug exposure record for the verbatim concept observed during 30d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(de1.drug_concept_id AS BIGINT) * 1000 + 402 AS covariate_id,
--	de1.drug_concept_id AS concept_id
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(de1.drug_concept_id AS BIGINT) * 1000 + 402 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(de1.drug_concept_id AS BIGINT) * 1000 + 402
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug exposure record for the concept or any its descendants observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	412 AS analysis_id,
--	'Drug exposure record for the concept or any its descendants observed during 30d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 412 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 412 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER JOIN drug_exposure de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_exposure_start_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 412
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;



/**************************
***************************
DRUG ERA
***************************
**************************/

IF OBJECT_ID('tempdb..#concept_ancestor_grouping', 'U') IS NOT NULL
	drop table #concept_ancestor_grouping;

select ca1.ancestor_concept_id, ca1.descendant_concept_id
into #concept_ancestor_grouping
from @cdmDatabaseSchema.concept_ancestor ca1
inner join
(
	select concept_id
	from @cdmDatabaseSchema.concept
	where (vocabulary_id = 'ATC' and len(concept_code) in (3, 4, 5))
		OR (vocabulary_id = 'RxNorm' and concept_class_id in ('Ingredient'))
) t1
on ca1.ancestor_concept_id = t1.concept_id
;


--drug exist:  episode in last 365d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug era record for the verbatim concept observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	501 AS analysis_id,
--	'Drug era record for the verbatim concept observed during 365d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'365d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(de1.drug_concept_id AS BIGINT) * 1000 + 501 AS covariate_id,
--	de1.drug_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= dateadd(dd,-365,cc1.cohort_start_date) 
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(de1.drug_concept_id AS BIGINT) * 1000 + 501 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= dateadd(dd,-365,cc1.cohort_start_date) 
--GROUP BY cc1.cohort_definition_id, CAST(de1.drug_concept_id AS BIGINT) * 1000 + 501
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--using aggregate concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Drug era record for the concept or any its descendants observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	511 AS analysis_id,
	'Drug era record for the concept or any its descendants observed during 365d on or prior to cohort index' AS analysis_name,
	'Drug' AS domain_id,
	'365d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 511 AS covariate_id,
	cag1.ancestor_concept_id AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.drug_era de1
	ON cc1.person_id = de1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON de1.drug_concept_id = cag1.descendant_concept_id
WHERE de1.drug_concept_id > 0
	AND de1.drug_era_start_date <= cc1.cohort_start_date
	AND de1.drug_era_end_date >= dateadd(dd,-365,cc1.cohort_start_date) ) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 511 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
inner join @cdmDatabaseSchema.drug_era de1
	ON cc1.person_id = de1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON de1.drug_concept_id = cag1.descendant_concept_id
WHERE de1.drug_concept_id > 0
	AND de1.drug_era_start_date <= cc1.cohort_start_date
	AND de1.drug_era_end_date >= dateadd(dd,-365,cc1.cohort_start_date) 
GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 511
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;





----drug exist:  episode in last 30d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug era record for the verbatim concept observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	502 AS analysis_id,
--	'Drug era record for the verbatim concept observed during 30d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(de1.drug_concept_id AS BIGINT) * 1000 + 502 AS covariate_id,
--	de1.drug_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= dateadd(dd,-30,cc1.cohort_start_date) 
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(de1.drug_concept_id AS BIGINT) * 1000 + 502 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--		AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= dateadd(dd,-30,cc1.cohort_start_date) 
--GROUP BY cc1.cohort_definition_id, CAST(de1.drug_concept_id AS BIGINT) * 1000 + 502
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug era record for the concept or any its descendants observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	512 AS analysis_id,
--	'Drug era record for the concept or any its descendants observed during 30d on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 512 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= dateadd(dd,-30,cc1.cohort_start_date) 
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 512 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= dateadd(dd,-30,cc1.cohort_start_date) 
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 512
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;



----drug exist:  episode overlaps in index
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug era record for the verbatim concept observed concurrent (overlapping) with cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	503 AS analysis_id,
--	'Drug era record for the verbatim concept observed concurrent (overlapping) with cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'concurrent (overlapping) with cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(de1.drug_concept_id AS BIGINT) * 1000 + 503 AS covariate_id,
--	de1.drug_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= cc1.cohort_start_date 
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(de1.drug_concept_id AS BIGINT) * 1000 + 503 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--		AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= cc1.cohort_start_date 
--GROUP BY cc1.cohort_definition_id, CAST(de1.drug_concept_id AS BIGINT) * 1000 + 503
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug era record for the concept or any its descendants observed concurrent (overlapping) with cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	513 AS analysis_id,
--	'Drug era record for the concept or any its descendants observed concurrent (overlapping) with cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'concurrent (overlapping) with cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 513 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= cc1.cohort_start_date 
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 513 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON de1.drug_concept_id = cag1.descendant_concept_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--	AND de1.drug_era_end_date >= cc1.cohort_start_date 
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 513
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--drug exist:  episode occurs anytime on or prior index
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Drug era record for the verbatim concept observed anytime on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	504 AS analysis_id,
--	'Drug era record for the verbatim concept observed anytime on or prior to cohort index' AS analysis_name,
--	'Drug' AS domain_id,
--	'anytime on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(de1.drug_concept_id AS BIGINT) * 1000 + 504 AS covariate_id,
--	de1.drug_concept_id AS concept_id
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--	AND de1.drug_era_start_date <= cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(de1.drug_concept_id AS BIGINT) * 1000 + 504 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--inner join @cdmDatabaseSchema.drug_era de1
--	ON cc1.person_id = de1.person_id
--WHERE de1.drug_concept_id > 0
--		AND de1.drug_era_start_date <= cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(de1.drug_concept_id AS BIGINT) * 1000 + 504
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--using aggregate concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Drug era record for the concept or any its descendants observed anytime on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	514 AS analysis_id,
	'Drug era record for the concept or any its descendants observed anytime on or prior to cohort index' AS analysis_name,
	'Drug' AS domain_id,
	'anytime on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 514 AS covariate_id,
	cag1.ancestor_concept_id AS concept_id
FROM #cohort cc1
inner join @cdmDatabaseSchema.drug_era de1
	ON cc1.person_id = de1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON de1.drug_concept_id = cag1.descendant_concept_id
WHERE de1.drug_concept_id > 0
	AND de1.drug_era_start_date <= cc1.cohort_start_date
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 514 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
inner join @cdmDatabaseSchema.drug_era de1
	ON cc1.person_id = de1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON de1.drug_concept_id = cag1.descendant_concept_id
WHERE de1.drug_concept_id > 0
	AND de1.drug_era_start_date <= cc1.cohort_start_date
GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 514
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




--601: Number of ingredients within the drug group observed all time on or prior to cohort index
--NOT IMPLEMENTED YET, it's problematic at aggregate summary level


/**************************
***************************
PROCEDURE OCCURRENCE
***************************
**************************/

IF OBJECT_ID('tempdb..#concept_ancestor_grouping', 'U') IS NOT NULL
	drop table #concept_ancestor_grouping;

select ca1.ancestor_concept_id, ca1.descendant_concept_id
into #concept_ancestor_grouping
from @cdmDatabaseSchema.concept_ancestor ca1
inner join
(
	select concept_id
	from @cdmDatabaseSchema.concept
	where vocabulary_id = 'SNOMED' and domain_id = 'Procedure'
	and concept_id not in (select descendant_concept_id from @cdmDatabaseSchema.concept_ancestor 
		where ancestor_concept_id in (4033552,4036803,4102442)
		 or descendant_concept_id in (4306780)
		 or (ancestor_concept_id = 4322976 and max_levels_of_separation <= 1)
		 )
) t1
on ca1.ancestor_concept_id = t1.concept_id
;


--procedures exist:  episode in last 365d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Procedure occurrence record for the verbatim concept observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	701 AS analysis_id,
--	'Procedure occurrence record for the verbatim concept observed during 365d on or prior to cohort index' AS analysis_name,
--	'Procedure' AS domain_id,
--	'365d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(po1.procedure_concept_id AS BIGINT) * 1000 + 701 AS covariate_id,
--	po1.procedure_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.procedure_occurrence po1
--	ON cc1.person_id = po1.person_id
--WHERE po1.procedure_concept_id > 0
--	AND po1.procedure_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(po1.procedure_concept_id AS BIGINT) * 1000 + 701 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.procedure_occurrence po1
--	ON cc1.person_id = po1.person_id
--WHERE po1.procedure_concept_id > 0
--	AND po1.procedure_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(po1.procedure_concept_id AS BIGINT) * 1000 + 701
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--using aggregate concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Procedure occurrence record for the concept or any its descendants observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	711 AS analysis_id,
	'Procedure occurrence record for the concept or any its descendants observed during 365d on or prior to cohort index' AS analysis_name,
	'Procedure' AS domain_id,
	'365d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 711 AS covariate_id,
	cag1.ancestor_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.procedure_occurrence po1
	ON cc1.person_id = po1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON po1.procedure_concept_id = cag1.descendant_concept_id
WHERE po1.procedure_concept_id > 0
	AND po1.procedure_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 711 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER join @cdmDatabaseSchema.procedure_occurrence po1
	ON cc1.person_id = po1.person_id
INNER JOIN #concept_ancestor_grouping cag1
	ON po1.procedure_concept_id = cag1.descendant_concept_id
WHERE po1.procedure_concept_id > 0
	AND po1.procedure_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 711
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;



----procedures exist:  episode in last 30d prior
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Procedure occurrence record for the verbatim concept observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	702 AS analysis_id,
--	'Procedure occurrence record for the verbatim concept observed during 30d on or prior to cohort index' AS analysis_name,
--	'Procedure' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(po1.procedure_concept_id AS BIGINT) * 1000 + 702 AS covariate_id,
--	po1.procedure_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.procedure_occurrence po1
--	ON cc1.person_id = po1.person_id
--WHERE po1.procedure_concept_id > 0
--	AND po1.procedure_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(po1.procedure_concept_id AS BIGINT) * 1000 + 702 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.procedure_occurrence po1
--	ON cc1.person_id = po1.person_id
--WHERE po1.procedure_concept_id > 0
--	AND po1.procedure_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(po1.procedure_concept_id AS BIGINT) * 1000 + 702
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




----using aggregate concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Procedure occurrence record for the concept or any its descendants observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	712 AS analysis_id,
--	'Procedure occurrence record for the concept or any its descendants observed during 30d on or prior to cohort index' AS analysis_name,
--	'Procedure' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 712 AS covariate_id,
--	cag1.ancestor_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.procedure_occurrence po1
--	ON cc1.person_id = po1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON po1.procedure_concept_id = cag1.descendant_concept_id
--WHERE po1.procedure_concept_id > 0
--	AND po1.procedure_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 712 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.procedure_occurrence po1
--	ON cc1.person_id = po1.person_id
--INNER JOIN #concept_ancestor_grouping cag1
--	ON po1.procedure_concept_id = cag1.descendant_concept_id
--WHERE po1.procedure_concept_id > 0
--	AND po1.procedure_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(cag1.ancestor_concept_id AS BIGINT) * 1000 + 712
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;



/**************************
***************************
OBSERVATION
***************************
**************************/




/**************************
***************************
MEASUREMENT
***************************
**************************/

--measurement exists in 365d on or prior
--using verbatim concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Measurement record for the verbatim concept observed during 365d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	901 AS analysis_id,
	'Measurement record for the verbatim concept observed during 365d on or prior to cohort index' AS analysis_name,
	'Measurement' AS domain_id,
	'365d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 901 AS covariate_id,
	m1.measurement_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 901 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
GROUP BY cc1.cohort_definition_id, CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 901
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




--measurement exists in 365d on or prior with value_as_number > 0 or concept>0
--using verbatim concept
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Measurement record for the verbatim concept observed during 365d on or prior to cohort index with a value  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	902 AS analysis_id,
	'Measurement record for the verbatim concept observed during 365d on or prior to cohort index with a value' AS analysis_name,
	'Measurement' AS domain_id,
	'365d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 902 AS covariate_id,
	m1.measurement_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
	AND (m1.value_as_number > 0 or m1.value_as_concept_id > 0)
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT cc1.cohort_definition_id,
	CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 902 AS covariate_id,
	count(distinct cc1.person_id) AS count_value
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-365,cc1.cohort_start_date) AND cc1.cohort_start_date
	AND (m1.value_as_number > 0 or m1.value_as_concept_id > 0)
GROUP BY cc1.cohort_definition_id, CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 902
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;


----measurement exists in 30d on or prior: 902
----using verbatim concept
--INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
--SELECT t1.covariate_id,
--	'Measurement record for the verbatim concept observed during 30d on or prior to cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
--		WHEN c1.concept_name IS NOT NULL
--			THEN c1.concept_name
--		ELSE 'Unknown invalid concept'
--		END AS covariate_name,
--	902 AS analysis_id,
--	'Measurement record for the verbatim concept observed during 30d on or prior to cohort index' AS analysis_name,
--	'Measurement' AS domain_id,
--	'30d on or prior to cohort index' AS time_window,
--	t1.concept_id AS concept_id
--FROM
--(
--SELECT DISTINCT CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 902 AS covariate_id,
--	m1.measurement_concept_id AS concept_id
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.measurement m1
--	ON cc1.person_id = m1.person_id
--WHERE m1.measurement_concept_id > 0
--	AND m1.measurement_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--) t1
--LEFT join @cdmDatabaseSchema.concept c1
--ON t1.concept_id = c1.concept_id
--;



--INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
--SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
--FROM
--(
--SELECT cc1.cohort_definition_id,
--	CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 902 AS covariate_id,
--	count(distinct cc1.person_id) AS count_value
--FROM #cohort cc1
--INNER join @cdmDatabaseSchema.measurement m1
--	ON cc1.person_id = m1.person_id
--WHERE m1.measurement_concept_id > 0
--	AND m1.measurement_date BETWEEN dateadd(dd,-30,cc1.cohort_start_date) AND cc1.cohort_start_date
--GROUP BY cc1.cohort_definition_id, CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 902
--) t1
--INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
--	ON t1.cohort_definition_id = t2.cohort_definition_id
--;




--for numeric values with valid range, latest value within 180 below low

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Measurement numeric value below normal range for latest value within 180d of cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	903 AS analysis_id,
	'Measurement numeric value below normal range for latest value within 180d of cohort index' AS analysis_name,
	'Measurement' AS domain_id,
	'180d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 903 AS covariate_id,
	m1.measurement_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
	AND m1.value_as_number >= 0
	AND m1.range_low >= 0
	AND m1.range_high >= 0
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT t0.cohort_definition_id,
	CAST(t0.measurement_concept_id AS BIGINT) * 1000 + 903 AS covariate_id,
	count(distinct t0.person_id) AS count_value
FROM (
	SELECT cc1.cohort_definition_id,
		cc1.person_id,
		m1.measurement_concept_id,
		m1.value_as_number,
		m1.range_low,
		m1.range_high,
		ROW_NUMBER() OVER (PARTITION BY cc1.cohort_definition_id, cc1.person_id, m1.measurement_concept_id ORDER BY m1.measurement_date DESC) AS rn1
	FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
	WHERE m1.measurement_concept_id != 0
		AND m1.measurement_date <= cc1.cohort_start_date
		AND m1.measurement_date >= dateadd(dd, -180, cc1.cohort_start_date)
		AND m1.value_as_number >= 0
		AND m1.range_low >= 0
		AND m1.range_high >= 0
	) t0
WHERE RN1 = 1
	AND VALUE_AS_NUMBER < RANGE_LOW
GROUP BY t0.cohort_definition_id,
	CAST(t0.measurement_concept_id AS BIGINT) * 1000 + 903
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;



--for numeric values with valid range, latest value above high: 904

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Measurement numeric value above normal range for latest value within 180d of cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	904 AS analysis_id,
	'Measurement numeric value above normal range for latest value within 180d of cohort index' AS analysis_name,
	'Measurement' AS domain_id,
	'180d on or prior to cohort index' AS time_window,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 904 AS covariate_id,
	m1.measurement_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
	AND m1.value_as_number >= 0
	AND m1.range_low >= 0
	AND m1.range_high >= 0
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
SELECT t0.cohort_definition_id,
	CAST(t0.measurement_concept_id AS BIGINT) * 1000 + 904 AS covariate_id,
	count(distinct t0.person_id) AS count_value
FROM
	(
	SELECT cc1.cohort_definition_id,
		cc1.person_id,
		m1.measurement_concept_id,
		m1.value_as_number,
		m1.range_low,
		m1.range_high,
		ROW_NUMBER() OVER (PARTITION BY cc1.cohort_definition_id, cc1.person_id, m1.measurement_concept_id ORDER BY m1.measurement_date DESC) AS rn1
	FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
	WHERE m1.measurement_concept_id != 0
		AND m1.measurement_date <= cc1.cohort_start_date
		AND m1.measurement_date >= dateadd(dd, -180, cc1.cohort_start_date)
		AND m1.value_as_number >= 0
		AND m1.range_low >= 0
		AND m1.range_high >= 0
	) t0
WHERE RN1 = 1
	AND VALUE_AS_NUMBER > RANGE_HIGH
GROUP BY t0.cohort_definition_id,
	CAST(t0.measurement_concept_id AS BIGINT) * 1000 + 904
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;





--NOT IMPLEMENTED
--number of measurements:  episode in last 365d prior: 905

/****
NOT YET READY FOR PRIMETIME:   extreme values screw up the distributions.   need to normalize the range and remove outliers intelligently

--NEW COVARIATE.....distribution of values  (select 'primary' unit)
CREATE TABLE #primary_measurement_unit WITH (location=user_db, distribution=replicate) AS 
SELECT measurement_concept_id, unit_concept_id
FROM
(
SELECT measurement_concept_id, unit_concept_id, ROW_NUMBER() OVER (partition by measurement_concept_id, unit_concept_id ORDER by num_records desc) as rn1
FROM
(
SELECT measurement_concept_id, unit_concept_id, count(person_id) as num_records
FROM measurement
WHERE value_as_number >= 0
GROUP BY measurement_concept_id, unit_concept_id
) t1
) t2
WHERE rn1 = 1
;



INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT t1.covariate_id,
	'Distribution of latest measurement numeric value within 180d of cohort index:  ' + CAST(t1.concept_id AS VARCHAR) + '-' + CASE
		WHEN c1.concept_name IS NOT NULL
			THEN c1.concept_name
		ELSE 'Unknown invalid concept'
		END AS covariate_name,
	906 AS analysis_id,
	t1.concept_id AS concept_id
FROM
(
SELECT DISTINCT CAST(m1.measurement_concept_id AS BIGINT) * 1000 + 906 AS covariate_id,
	m1.measurement_concept_id AS concept_id
FROM #cohort cc1
INNER join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
INNER JOIN #primary_measurement_unit pmu1
		on m1.measurement_concept_id = pmu1.measurement_concept_id
		and m1.unit_concept_id = pmu1.unit_concept_id
WHERE m1.measurement_concept_id > 0
	AND m1.measurement_date BETWEEN dateadd(dd,-180,cc1.cohort_start_date) AND cc1.cohort_start_date
	AND m1.value_as_number >= 0
) t1
LEFT join @cdmDatabaseSchema.concept c1
ON t1.concept_id = c1.concept_id
;



CREATE TABLE #tempResults with (location=user_db, distribution=replicate) AS
with rawData (cohort_definition_id, covariate_id, person_id, stat_value) as
(
	select cohort_definition_id,
		CAST(t0.measurement_concept_id AS BIGINT) * 1000 + 906 as covariate_id,
		person_id,
		value_as_number AS stat_value
	FROM
	(
		SELECT cc1.cohort_definition_id,
			cc1.person_id,
			m1.measurement_concept_id,
			m1.value_as_number,
			ROW_NUMBER() OVER (PARTITION BY cc1.cohort_definition_id, cc1.person_id, m1.measurement_concept_id ORDER BY m1.measurement_date DESC) AS rn1
		FROM #cohort cc1
		INNER join @cdmDatabaseSchema.measurement m1
		ON cc1.person_id = m1.person_id
		INNER JOIN #primary_measurement_unit pmu1
		on m1.measurement_concept_id = pmu1.measurement_concept_id
		and m1.unit_concept_id = pmu1.unit_concept_id
		WHERE m1.measurement_concept_id != 0
			AND m1.measurement_date <= cc1.cohort_start_date
			AND m1.measurement_date >= dateadd(dd, -180, cc1.cohort_start_date)
			AND m1.value_as_number >= 0
	) t0
	WHERE RN1 = 1

),
overallStats (cohort_definition_id, covariate_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  covariate_id,
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id, covariate_id
),
Stats (cohort_definition_id, covariate_id, stat_value, total, rn) as
(
  select cohort_definition_id, covariate_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, covariate_id, stat_value
),
StatsPrior (cohort_definition_id, covariate_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.covariate_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p 
	on s.cohort_definition_id = p.cohort_definition_id
	and s.covariate_id = p.covariate_id 
	and p.rn <= s.rn
  group by s.cohort_definition_id, s.covariate_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	o.covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
AND p.covariate_id = o.covariate_id
group by o.cohort_definition_id, o.covariate_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;

*******/


/**************************
***************************
DATA DENSITY CONCEPT COUNTS
***************************
**************************/

--Number of distinct conditions observed in 365d on or prior to cohort index

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1000,
	'Number of distinct conditions observed in 365d on or prior to cohort index',
	1000,
	'Number of distinct conditions observed in 365d on or prior to cohort index',
	'Condition',
	'365d on or prior to cohort index',
	0
	);









with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, case when ce1.person_id is null then 0 else count(distinct ce1.condition_concept_id) end as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.condition_era ce1
	ON cc1.person_id = ce1.person_id
	AND ce1.condition_era_start_date <= cc1.cohort_start_date
	AND ce1.condition_era_end_date >= dateadd(dd, -365, cc1.cohort_start_date)
	GROUP BY cc1.cohort_definition_id, cc1.person_id, ce1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1000 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;





--Number of distinct drugs observed in 365d on or prior to cohort index

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1001,
	'Number of distinct drugs observed in 365d on or prior to cohort index',
	1001,
	'Number of distinct drugs observed in 365d on or prior to cohort index',
	'Drug',
	'365d on or prior to cohort index',
	0
	);



CREATE TABLE #tempResults with (location=user_db, distribution=replicate) AS
with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, case when de1.person_id is null then 0 else count(distinct de1.drug_concept_id) end as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.drug_era de1
	ON cc1.person_id = de1.person_id
	AND de1.drug_era_start_date <= cc1.cohort_start_date
	AND de1.drug_era_end_date >= dateadd(dd, -365, cc1.cohort_start_date)
	GROUP BY cc1.cohort_definition_id, cc1.person_id, de1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1001 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;



--Number of distinct procedures observed in 365d on or prior to cohort index

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1002,
	'Number of distinct procedures observed in 365d on or prior to cohort index',
	1002,
	'Number of distinct procedures observed in 365d on or prior to cohort index',
	'Procedure',
	'365d on or prior to cohort index',
	0
	);



with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, case when po1.person_id is null then 0 else count(distinct po1.procedure_concept_id) end as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.procedure_occurrence po1
	ON cc1.person_id = po1.person_id
	AND po1.procedure_date <= cc1.cohort_start_date
	AND po1.procedure_date >= dateadd(dd, -365, cc1.cohort_start_date)
	GROUP BY cc1.cohort_definition_id, cc1.person_id, po1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1002 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;


--Number of distinct observations observed in 365d on or prior to cohort index

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1003,
	'Number of distinct observations observed in 365d on or prior to cohort index',
	1003,
	'Number of distinct observations observed in 365d on or prior to cohort index',
	'Observation',
	'365d on or prior to cohort index',
	0
	);



with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, case when o1.person_id is null then 0 else count(distinct o1.observation_concept_id) end as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.observation o1
	ON cc1.person_id = o1.person_id
	AND o1.observation_date <= cc1.cohort_start_date
	AND o1.observation_date >= dateadd(dd, -365, cc1.cohort_start_date)
	GROUP BY cc1.cohort_definition_id, cc1.person_id, o1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1003 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;





--Number of visits observed in 365d on or prior to cohort index: 1004
INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1004,
	'Number of visits observed in 365d on or prior to cohort index',
	1004,
	'Number of visits observed in 365d on or prior to cohort index',
	'Visit',
	'365d on or prior to cohort index',
	0
	);



with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, count(vo1.visit_occurrence_id) as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.visit_occurrence vo1
	ON cc1.person_id = vo1.person_id
	AND vo1.visit_start_date <= cc1.cohort_start_date
	AND vo1.visit_end_date >= dateadd(dd, -365, cc1.cohort_start_date)
	GROUP BY cc1.cohort_definition_id, cc1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1004 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;



--Number of inpatient visits observed in 365d on or prior to cohort index: 1005

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1005,
	'Number of inpatient visits observed in 365d on or prior to cohort index',
	1005,
	'Number of inpatient visits observed in 365d on or prior to cohort index',
	'Visit',
	'365d on or prior to cohort index',
	0
	);



with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, count(vo1.visit_occurrence_id) as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.visit_occurrence vo1
	ON cc1.person_id = vo1.person_id
	AND vo1.visit_start_date <= cc1.cohort_start_date
	AND vo1.visit_end_date >= dateadd(dd, -365, cc1.cohort_start_date)
	AND vo1.visit_concept_id = 9201
	GROUP BY cc1.cohort_definition_id, cc1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1005 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;


--Number of ER visits observed in 365d on or prior to cohort index: 1006

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1006,
	'Number of ER visits observed in 365d on or prior to cohort index',
	1006,
	'Number of ER visits observed in 365d on or prior to cohort index',
	'Visit',
	'365d on or prior to cohort index',
	0
	);


with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, count(vo1.visit_occurrence_id) as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.visit_occurrence vo1
	ON cc1.person_id = vo1.person_id
	AND vo1.visit_start_date <= cc1.cohort_start_date
	AND vo1.visit_end_date >= dateadd(dd, -365, cc1.cohort_start_date)
	AND vo1.visit_concept_id = 9203 /*ER*/
	GROUP BY cc1.cohort_definition_id, cc1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1006 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;




--Number of distinct measurements observed in 365d on or prior to cohort index

INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	1007,
	'Number of distinct measurements observed in 365d on or prior to cohort index',
	1007,
	'Number of distinct measurements observed in 365d on or prior to cohort index',
	'Measurement',
	'365d on or prior to cohort index',
	0
	);




with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id, cc1.person_id, case when m1.person_id is null then 0 else count(distinct m1.measurement_concept_id) end as stat_value
	FROM #cohort cc1
	LEFT join @cdmDatabaseSchema.measurement m1
	ON cc1.person_id = m1.person_id
	AND m1.measurement_date <= cc1.cohort_start_date
	AND m1.measurement_date >= dateadd(dd, -365, cc1.cohort_start_date)
	GROUP BY cc1.cohort_definition_id, cc1.person_id, m1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	1007 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;


INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;







/**************************
***************************
RISK SCORES
***************************
**************************/

--CHARLSON

IF OBJECT_ID('tempdb..#Charlson_concepts', 'U') IS NOT NULL
  DROP TABLE #Charlson_concepts;

CREATE TABLE #Charlson_concepts (
	diag_category_id INT,
	concept_id INT
	) WITH (location=user_db, distribution=replicate);

IF OBJECT_ID('tempdb..#Charlson_scoring', 'U') IS NOT NULL
	DROP TABLE #Charlson_scoring;

CREATE TABLE #Charlson_scoring (
	diag_category_id INT,
	diag_category_name VARCHAR(255),
	weight INT
	) WITH (location=user_db, distribution=replicate);

--acute myocardial infarction
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (1,'Myocardial infarction',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 1, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id IN (329847)
;

--Congestive heart failure
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (2,'Congestive heart failure',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 2, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (316139)
;


--Peripheral vascular disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (3,'Peripheral vascular disease',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 3, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (321052)
;

--Cerebrovascular disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (4,'Cerebrovascular disease',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 4, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (381591, 434056)
;

--Dementia
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (5,'Dementia',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 5, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4182210)
;

--Chronic pulmonary disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (6,'Chronic pulmonary disease',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 6, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4063381)
;

--Rheumatologic disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (7,'Rheumatologic disease',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 7, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (257628, 134442, 80800, 80809, 256197, 255348)
;

--Peptic ulcer disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (8,'Peptic ulcer disease',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 8, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4247120)
;

--Mild liver disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (9,'Mild liver disease',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 9, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4064161, 4212540)
;

--Diabetes (mild to moderate)
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (10,'Diabetes (mild to moderate)',1);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 10, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (201820)
;

--Diabetes with chronic complications
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (11,'Diabetes with chronic complications',2);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 11, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4192279, 443767, 442793)
;

--Hemoplegia or paralegia
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (12,'Hemoplegia or paralegia',2);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 12, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (192606, 374022)
;

--Renal disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (13,'Renal disease',2);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 13, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4030518)
;

--Any malignancy
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (14,'Any malignancy',2);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 14, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (443392)
;

--Moderate to severe liver disease
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (15,'Moderate to severe liver disease',3);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 15, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (4245975, 4029488, 192680, 24966)
;

--Metastatic solid tumor
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (16,'Metastatic solid tumor',6);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 16, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (432851)
;

--AIDS
INSERT INTO #Charlson_scoring (diag_category_id,diag_category_name,weight)
VALUES (17,'AIDS',6);

INSERT INTO #Charlson_concepts (diag_category_id,concept_id)
SELECT 17, descendant_concept_id
from @cdmDatabaseSchema.concept_ancestor
WHERE ancestor_concept_id in (439727)
;


INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
VALUES (
	-1100,
	'Charlson Index - Romano adaptation, using conditions all time on or prior to cohort index',
	1100,
	'Charlson Index - Romano adaptation, using conditions all time on or prior to cohort index',
	'Condition',
	'anytime on or prior to cohort index',
	0
	);


INSERT INTO #cohort_summary_analysis_ref (covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id)
SELECT DISTINCT 1100 + t0.stat_value AS covariate_id,
	'Charlson Index - Romano adaptation, using conditions all time on or prior to cohort index: score = ' + cast(t0.stat_value as varchar) AS covariate_name,
	1100,
	'Charlson Index - Romano adaptation, using conditions all time on or prior to cohort index',
	'Condition',
	'anytime on or prior to cohort index',
	0
	FROM
		(
		SELECT cc1.cohort_definition_id,
			cc1.person_id,
			SUM(case when t1.weight is null then 0 else t1.weight end) AS stat_value
		FROM 
			#cohort cc1
			LEFT JOIN
			(
			SELECT DISTINCT cc1.cohort_definition_id,
				cc1.person_id,
				cs1.diag_category_id,
				cs1.weight
			FROM #cohort cc1
			INNER join @cdmDatabaseSchema.condition_era ce1
				ON cc1.person_id = ce1.person_id
				AND ce1.condition_era_start_date <= cc1.cohort_start_date
			INNER JOIN #Charlson_concepts c1
				ON ce1.condition_concept_id = c1.concept_id
			INNER JOIN #Charlson_scoring cs1
				ON c1.diag_category_id = cs1.diag_category_id
			) t1
			ON cc1.cohort_definition_id = t1.cohort_definition_id
			AND cc1.person_id = t1.person_id
		GROUP BY cc1.cohort_definition_id, cc1.person_id
		) t0
	
;


--distribution by each value
INSERT INTO #cohort_summary_results (cohort_definition_id, covariate_id, count_value, stat_value)
SELECT t1.cohort_definition_id, t1.covariate_id, t1.count_value, 1.0*t1.count_value / t2.count_value as stat_value
FROM
(
	SELECT t0.cohort_definition_id,
		1100 + t0.stat_value AS covariate_id,
		count(distinct t0.person_id) AS count_value
	FROM
		(
		SELECT cc1.cohort_definition_id,
			cc1.person_id,
			SUM(case when t1.weight is null then 0 else t1.weight end) AS stat_value
		FROM 
			#cohort cc1
			LEFT JOIN
			(
			SELECT DISTINCT cc1.cohort_definition_id,
				cc1.person_id,
				cs1.diag_category_id,
				cs1.weight
			FROM #cohort cc1
			INNER join @cdmDatabaseSchema.condition_era ce1
				ON cc1.person_id = ce1.person_id
				AND ce1.condition_era_start_date <= cc1.cohort_start_date
			INNER JOIN #Charlson_concepts c1
				ON ce1.condition_concept_id = c1.concept_id
			INNER JOIN #Charlson_scoring cs1
				ON c1.diag_category_id = cs1.diag_category_id
			) t1
			ON cc1.cohort_definition_id = t1.cohort_definition_id
			AND cc1.person_id = t1.person_id
		GROUP BY cc1.cohort_definition_id, cc1.person_id
		) t0
		GROUP BY t0.cohort_definition_id,
		1100 + t0.stat_value
) t1
INNER JOIN (select cohort_definition_id, count_value from #cohort_summary_results where covariate_id = 0) t2
	ON t1.cohort_definition_id = t2.cohort_definition_id
;




--note and warning, persons with no prior events make statistics tricky

with rawData (cohort_definition_id, person_id, stat_value) as
(
	SELECT cc1.cohort_definition_id,
		cc1.person_id,
		SUM(case when t1.weight is null then 0 else t1.weight end) AS stat_value
	FROM 
		#cohort cc1
		LEFT JOIN
		(
		SELECT DISTINCT cc1.cohort_definition_id,
			cc1.person_id,
			cs1.diag_category_id,
			cs1.weight
		FROM #cohort cc1
		INNER join @cdmDatabaseSchema.condition_era ce1
			ON cc1.person_id = ce1.person_id
			AND ce1.condition_era_start_date <= cc1.cohort_start_date
		INNER JOIN #Charlson_concepts c1
			ON ce1.condition_concept_id = c1.concept_id
		INNER JOIN #Charlson_scoring cs1
			ON c1.diag_category_id = cs1.diag_category_id
		) t1
		ON cc1.cohort_definition_id = t1.cohort_definition_id
		AND cc1.person_id = t1.person_id
	GROUP BY cc1.cohort_definition_id, cc1.person_id
),
overallStats (cohort_definition_id, avg_value, stdev_value, min_value, max_value, total) as
(
  select cohort_definition_id, 
  avg(1.0 * stat_value) as avg_value,
  stdev(stat_value) as stdev_value,
  min(stat_value) as min_value,
  max(stat_value) as max_value,
  count_big(*) as total
  FROM rawData
  group by cohort_definition_id
),
Stats (cohort_definition_id, stat_value, total, rn) as
(
  select cohort_definition_id, stat_value, count_big(*) as total, row_number() over (partition by cohort_definition_id order by stat_value) as rn
  from rawData
  group by cohort_definition_id, stat_value
),
StatsPrior (cohort_definition_id, stat_value, total, accumulated) as
(
  select s.cohort_definition_id, s.stat_value, s.total, sum(p.total) as accumulated
  from Stats s
  join Stats p on s.cohort_definition_id = p.cohort_definition_id and p.rn <= s.rn
  group by s.cohort_definition_id, s.stat_value, s.total, s.rn
)
select o.cohort_definition_id,
	-1100 as covariate_id,
  o.total as count_value,
	o.min_value,
	o.max_value,
	o.avg_value,
	o.stdev_value,
	MIN(case when p.accumulated >= .50 * o.total then stat_value end) as median_value,
	MIN(case when p.accumulated >= .10 * o.total then stat_value end) as p10_value,
	MIN(case when p.accumulated >= .25 * o.total then stat_value end) as p25_value,
	MIN(case when p.accumulated >= .75 * o.total then stat_value end) as p75_value,
	MIN(case when p.accumulated >= .90 * o.total then stat_value end) as p90_value
into #tempResults
from StatsPrior p
INNER JOIN overallStats o
ON p.cohort_definition_id = o.cohort_definition_id
group by o.cohort_definition_id, o.total, o.min_value, o.max_value, o.avg_value, o.stdev_value
;

INSERT INTO #cohort_summary_results_dist (cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value)
select cohort_definition_id,covariate_id, count_value,min_value, max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value FROM #tempResults;

DROP TABLE #tempResults;


TRUNCATE TABLE #Charlson_concepts;

DROP TABLE #Charlson_concepts;

TRUNCATE TABLE #Charlson_scoring;

DROP TABLE #Charlson_scoring;







IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_analysis_ref', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_analysis_ref;

select covariate_id, covariate_name, analysis_id, analysis_name, domain_id, time_window, concept_id
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_analysis_ref
from #cohort_summary_analysis_ref;

IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results;

select cohort_definition_id, covariate_id, count_value, stat_value
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results
from #cohort_summary_results;

IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results_dist', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results_dist;


select cohort_definition_id, covariate_id, count_value, min_value,max_value,avg_value,stdev_value,median_value,p10_value,p25_value,p75_value,p90_value
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results_dist
from #cohort_summary_results_dist;














IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary;


select cc1.comparison_id, cc1.covariate_id, cc1.covariate_name, cc1.analysis_id, cc1.concept_id,
	cc1.domain_id, cc1.analysis_name, cc1.time_window,
	target_cohort.cohort_definition_id as target_cohort_definition_id,
	target_cohort.cohort_definition_name as target_cohort_definition_name,
	case when target_cohort.count_value is not null then target_cohort.count_value else 0 end as target_count_value,
	case when target_cohort.stat_value is not null then target_cohort.stat_value else 0 end as target_stat_value,
	comparator.cohort_definition_id as comparator_cohort_definition_id,
	comparator.cohort_definition_name as comparator_cohort_definition_name,
	case when comparator.count_value is not null then comparator.count_value else 0 end as comparator_count_value,
	case when comparator.stat_value is not null then comparator.stat_value else 0 end as comparator_stat_value,
	case when (target_cohort.stat_value is not null and target_cohort.stat_value < 1) or (comparator.stat_value is not null and comparator.stat_value < 1)
		then (target_cohort.stat_value - comparator.stat_value) / sqrt((target_cohort.stat_value*(1-target_cohort.stat_value) + comparator.stat_value*(1-comparator.stat_value))/2) else 0 end as standard_diff,
	abs(case when (target_cohort.stat_value is not null and target_cohort.stat_value < 1) or (comparator.stat_value is not null and comparator.stat_value < 1)
		then (target_cohort.stat_value - comparator.stat_value) / sqrt((target_cohort.stat_value*(1-target_cohort.stat_value) + comparator.stat_value*(1-comparator.stat_value))/2) else 0 end) as abs_standard_diff,
	case when target_cohort.stat_value is not null and comparator.stat_value is not null
		then target_cohort.stat_value / comparator.stat_value else 1 end as relative_risk

into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary
from

(select ccr1.comparison_id, csar1.covariate_id, csar1.covariate_name, csar1.analysis_id, csar1.concept_id, csar1.domain_id, csar1.analysis_name, csar1.time_window
from
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref ccr1,
(select csar0.* 
	from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_analysis_ref csar0 
	inner join
	(select distinct covariate_id from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results) c1
	on csar0.covariate_id = c1.covariate_id
) csar1
) cc1

inner join
(
select ccr1.comparison_id, ccr1.target_id as cohort_definition_id, ccr1.target_name as cohort_definition_name, csr1.covariate_id, csr1.count_value, csr1.stat_value
from
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results csr1
inner join
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref ccr1
on csr1.cohort_definition_id = ccr1.target_id
) target_cohort
on cc1.comparison_id = target_cohort.comparison_id
and cc1.covariate_id = target_cohort.covariate_id

inner join
(
select ccr1.comparison_id, ccr1.comparator_id as cohort_definition_id, ccr1.comparator_name as cohort_definition_name, csr1.covariate_id, csr1.count_value, csr1.stat_value
from
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results csr1
inner join
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref ccr1
on csr1.cohort_definition_id = ccr1.comparator_id
) comparator
on cc1.comparison_id = comparator.comparison_id
and cc1.covariate_id = comparator.covariate_id
;









IF OBJECT_ID('@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary_dist', 'U') IS NOT NULL
	drop table @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary_dist;


select cc1.comparison_id, cc1.covariate_id, cc1.covariate_name, cc1.analysis_id, cc1.concept_id,
	cc1.domain_id, cc1.analysis_name, cc1.time_window,
	target_cohort.cohort_definition_id as target_cohort_definition_id,
	target_cohort.cohort_definition_name as target_cohort_definition_name,
	case when target_cohort.count_value is not null then target_cohort.count_value else 0 end as target_count_value,
	case when target_cohort.avg_value is not null then target_cohort.avg_value else 0 end as target_avg_value,
	case when target_cohort.stdev_value is not null then target_cohort.stdev_value else 0 end as target_stdev_value,
	case when target_cohort.median_value is not null then target_cohort.median_value else 0 end as target_median_value,
	case when target_cohort.p10_value is not null then target_cohort.p10_value else 0 end as target_p10_value,
	case when target_cohort.p25_value is not null then target_cohort.p25_value else 0 end as target_p25_value,
	case when target_cohort.p75_value is not null then target_cohort.p75_value else 0 end as target_p75_value,
	case when target_cohort.p90_value is not null then target_cohort.p90_value else 0 end as target_p90_value,
	comparator.cohort_definition_id as comparator_cohort_definition_id,
	comparator.cohort_definition_name as comparator_cohort_definition_name,
	case when comparator.count_value is not null then comparator.count_value else 0 end as comparator_count_value,
	case when comparator.avg_value is not null then comparator.avg_value else 0 end as comparator_avg_value,
	case when comparator.stdev_value is not null then comparator.stdev_value else 0 end as comparator_stdev_value,
	case when comparator.median_value is not null then comparator.median_value else 0 end as comparator_median_value,
	case when comparator.p10_value is not null then comparator.p10_value else 0 end as comparator_p10_value,
	case when comparator.p25_value is not null then comparator.p25_value else 0 end as comparator_p25_value,
	case when comparator.p75_value is not null then comparator.p75_value else 0 end as comparator_p75_value,
	case when comparator.p90_value is not null then comparator.p90_value else 0 end as comparator_p90_value,
	case when target_cohort.stdev_value + comparator.stdev_value > 0
		then (target_cohort.avg_value - comparator.avg_value) / sqrt((target_cohort.stdev_value + comparator.stdev_value)/2) else 0 end as standard_diff,
	abs(case when target_cohort.stdev_value + comparator.stdev_value > 0
		then (target_cohort.avg_value - comparator.avg_value) / sqrt((target_cohort.stdev_value + comparator.stdev_value)/2) else 0 end) as abs_standard_diff,
	case when target_cohort.avg_value is not null and comparator.avg_value is not null and comparator.avg_value <> 0
		then target_cohort.avg_value / comparator.avg_value else 1 end as relative_risk
into @scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_summary_dist
from

(select ccr1.comparison_id, csar1.covariate_id, csar1.covariate_name, csar1.analysis_id, csar1.concept_id, csar1.domain_id, csar1.analysis_name, csar1.time_window
from
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref ccr1,
(select csar0.* 
	from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_analysis_ref csar0 
	inner join
	(select distinct covariate_id from @scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results_dist) c1
	on csar0.covariate_id = c1.covariate_id
) csar1
) cc1

inner join
(
select ccr1.comparison_id, ccr1.target_id as cohort_definition_id, ccr1.target_name as cohort_definition_name, csr1.covariate_id, csr1.count_value, csr1.avg_value, csr1.stdev_value, csr1.median_value, csr1.p10_value, csr1.p25_value, csr1.p75_value, csr1.p90_value
from
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results_dist csr1
inner join
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref ccr1
on csr1.cohort_definition_id = ccr1.target_id
) target_cohort
on cc1.comparison_id = target_cohort.comparison_id
and cc1.covariate_id = target_cohort.covariate_id

inner join
(
select ccr1.comparison_id, ccr1.comparator_id as cohort_definition_id, ccr1.comparator_name as cohort_definition_name, csr1.covariate_id, csr1.count_value, csr1.avg_value, csr1.stdev_value, csr1.median_value, csr1.p10_value, csr1.p25_value, csr1.p75_value, csr1.p90_value
from
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_summary_results_dist csr1
inner join
@scratchDatabaseSchema.@tablePrefix_LAB_cohort_comparison_ref  ccr1
on csr1.cohort_definition_id = ccr1.comparator_id
) comparator
on cc1.comparison_id = comparator.comparison_id
and cc1.covariate_id = comparator.covariate_id
;


