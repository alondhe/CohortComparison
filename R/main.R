


generateCovariates <- function(targetId, comparatorId)
{
  fileName <- paste(paste0("t", targetId), paste0("c", comparatorId), sep = "_")
  
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("cdmDbms"), 
                                                                  user = Sys.getenv("cdmUser"), 
                                                                  password = Sys.getenv("cdmPassword"), 
                                                                  server = Sys.getenv("cdmServer"),
                                                                  port = Sys.getenv("cdmServerPort"))
  
  covariateSettings <- FeatureExtraction::createCovariateSettings(useCovariateDemographics = TRUE,
                                                                  useCovariateDemographicsGender = TRUE,
                                                                  useCovariateDemographicsRace = TRUE,
                                                                  useCovariateDemographicsEthnicity = TRUE,
                                                                  useCovariateDemographicsAge = TRUE, 
                                                                  useCovariateDemographicsYear = TRUE,
                                                                  useCovariateDemographicsMonth = TRUE,
                                                                  useCovariateConditionOccurrence = TRUE,
                                                                  useCovariateConditionOccurrenceLongTerm = TRUE,
                                                                  useCovariateConditionOccurrenceShortTerm = TRUE,
                                                                  useCovariateConditionOccurrenceInptMediumTerm = TRUE,
                                                                  useCovariateConditionEra = TRUE,
                                                                  useCovariateConditionEraEver = TRUE,
                                                                  useCovariateConditionEraOverlap = TRUE,
                                                                  useCovariateConditionGroup = TRUE,
                                                                  useCovariateConditionGroupMeddra = TRUE,
                                                                  useCovariateConditionGroupSnomed = TRUE,
                                                                  useCovariateDrugExposure = TRUE,
                                                                  useCovariateDrugExposureLongTerm = TRUE,
                                                                  useCovariateDrugExposureShortTerm = TRUE, 
                                                                  useCovariateDrugEra = TRUE,
                                                                  useCovariateDrugEraLongTerm = TRUE, 
                                                                  useCovariateDrugEraShortTerm = TRUE,
                                                                  useCovariateDrugEraOverlap = TRUE, 
                                                                  useCovariateDrugEraEver = TRUE,
                                                                  useCovariateDrugGroup = TRUE, 
                                                                  useCovariateProcedureOccurrence = TRUE,
                                                                  useCovariateProcedureOccurrenceLongTerm = TRUE,
                                                                  useCovariateProcedureOccurrenceShortTerm = TRUE,
                                                                  useCovariateProcedureGroup = TRUE, 
                                                                  useCovariateObservation = TRUE,
                                                                  useCovariateObservationLongTerm = TRUE,
                                                                  useCovariateObservationShortTerm = TRUE,
                                                                  useCovariateObservationCountLongTerm = TRUE,
                                                                  useCovariateMeasurement = TRUE, 
                                                                  useCovariateMeasurementLongTerm = TRUE,
                                                                  useCovariateMeasurementShortTerm = TRUE,
                                                                  useCovariateMeasurementCountLongTerm = TRUE,
                                                                  useCovariateMeasurementBelow = TRUE,
                                                                  useCovariateMeasurementAbove = TRUE, 
                                                                  useCovariateConceptCounts = TRUE,
                                                                  useCovariateRiskScores = TRUE, 
                                                                  useCovariateRiskScoresCharlson = TRUE,
                                                                  useCovariateRiskScoresDCSI = TRUE, 
                                                                  useCovariateRiskScoresCHADS2 = TRUE,
                                                                  useCovariateRiskScoresCHADS2VASc = TRUE,
                                                                  useCovariateInteractionYear = TRUE, 
                                                                  useCovariateInteractionMonth = TRUE,
                                                                  excludedCovariateConceptIds = c(), 
                                                                  addDescendantsToExclude = TRUE,
                                                                  includedCovariateConceptIds = c(), 
                                                                  addDescendantsToInclude = TRUE,
                                                                  deleteCovariatesSmallCount = 100, 
                                                                  longTermDays = 365,
                                                                  mediumTermDays = 180, 
                                                                  shortTermDays = 30, 
                                                                  windowEndDays = 0)
  
  covariateData <- FeatureExtraction::getDbCovariateData(connectionDetails = connectionDetails, 
                                        cdmDatabaseSchema = cdmDatabaseSchema,  
                                        cdmVersion = '5.0.1', cohortIds = c(targetId, comparatorId), 
                                        covariateSettings = covariateSettings)
  
  saveRDS(object = covariateData, file = )
  
}



#' @export
getComparisons <- function()
{
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("cdmDbms"), 
                                                                  user = Sys.getenv("cdmUser"), 
                                                                  password = Sys.getenv("cdmPassword"), 
                                                                  server = Sys.getenv("cdmServer"),
                                                                  port = Sys.getenv("cdmServerPort"))
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "getComparisonDefinitions.sql", 
                                            packageName = "CohortComparison", 
                                            dbms = connectionDetails$dbms, 
                                            scratchDatabaseSchema = Sys.getenv("scratchDatabaseSchema"))
  connection <- connect(connectionDetails)
  data <- DatabaseConnector::querySql(connection = connection, sql = sql)
  return (data)
}


#' @export
getFeatures <- function(targetId, comparatorId)
{
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("cdmDbms"), 
                                                                  user = Sys.getenv("cdmUser"), 
                                                                  password = Sys.getenv("cdmPassword"), 
                                                                  server = Sys.getenv("cdmServer"),
                                                                  port = Sys.getenv("cdmServerPort"))
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "getSummaryData.sql", 
                                           packageName = "CohortComparison", 
                                           dbms = connectionDetails$dbms, 
                                           scratchDatabaseSchema = "scratch.dbo",
                                           cdmDatabaseSchema = Sys.getenv("cdmDatabaseSchema"),
                                           targetId = targetId,
                                           comparatorId = comparatorId)
  connection <- connect(connectionDetails)
  data <- DatabaseConnector::querySql(connection = connection, sql = sql)
  return (data)
}