


#' Build T vs C comparison object
#'
#' @description                   Logically groups targets and comparator Ids
#' @param targetId                The Id of the target cohort
#' @param comparatorId            The Id of the comparator cohort
#' @return                        An object containing the targetId and comparatorId
#'
#' @export
buildComparison <- function(targetId, comparatorId)
{
  comparison <- {}
  comparison$targetId <- targetId
  comparison$comparatorId <- comparatorId
  return (comparison)
}

#' Wrapper for Sql script to generate covariates of cohort
#'
#' @description                   Wrapper for Sql script to generate covariates
#' @param connectionDetails       The connection details of the database, as generated using \code{createConnectionDetails}
#' @param repoConnectionDetails   The connection details of the OHDSI Repo database, as generated using \code{createConnectionDetails}
#' @param cdmDatabaseSchema       The fully qualified name of the database schema holding the CDM data
#' @param ohdsiRepositorySchema   The fully qualified name of the database schema holding the OHDSI Repo
#' @param scratchDatabaseSchema   The fully qualified name of the scratch database schema
#' @param tablePrefix             The prefix of all scratch tables
#' @param webApiPrefix            The URL name of the WebAPI instance
#' @param useHttps                Should SSL be used?
#' @param cdmVersion              The version of the CDM database
#' @param comparisons             List of cohort comparisons, each of type \code{buildComparison}
#'
#' @export
generateSqlCovariates <- function(connectionDetails, 
                                  repoConnectionDetails,
                                  cdmDatabaseSchema,
                                  ohdsiRepositorySchema,
                                  scratchDatabaseSchema,
                                  tablePrefix,
                                  webApiPrefix,
                                  useHttps,
                                  cdmVersion, 
                                  comparisons)
{
  
  queryCohortDefName <- function(ohdsiRepositorySchema, cohortDefinitionId)
  {
    sql <- SqlRender::renderSql("select name from @ohdsiRepositorySchema.cohort_definition 
                                where id = @cohortDefinitionId",
                                ohdsiRepositorySchema = ohdsiRepositorySchema,
                                cohortDefinitionId = cohortDefinitionId)$sql
    connection <- DatabaseConnector::connect(connectionDetails = repoConnectionDetails)
    name <- DatabaseConnector::querySql(connection = connection, sql = sql)
    DatabaseConnector::disconnect(connection = connection)
    return(str_replace_all(str_replace_all(str_replace_all(
      name, " ", "_"), 
      "\\[(.*?)\\]_", ""), "_", " "))
  }
  
  cohortDefinitionIds <- unique(c(lapply(comparisons, '[[', 'targetId'), lapply(comparisons, '[[', 'comparatorId')))
  cohortDefinitionSqls <- lapply(X = cohortDefinitionIds, 
    function(cohortDefinitionId)
    {
      sql <- SqlRender::renderSql("select @cohortDefinitionId as cohort_id, '@cohortName' as cohort_name",
                                  cohortDefinitionId = cohortDefinitionId,
                                  cohortName = getFormattedCohortName(webApiPrefix = webApiPrefix, 
                                                                      cohortDefinitionId = cohortDefinitionId, 
                                                                      useHttps = useHttps))$sql
    })
  
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "createRef.sql",
                                           packageName = "CohortComparison", 
                                           dbms = connectionDetails$dbms,
                                           scratchDatabaseSchema = scratchDatabaseSchema,
                                           tablePrefix = tablePrefix,
                                           cohortDefinitionSqls = paste(cohortDefinitionSqls, collapse = "\nunion all\n"))
  
  
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  DatabaseConnector::executeSql(connection = connection, sql = sql)
  DatabaseConnector::disconnect(connection = connection)
  
  indexes <- c(1:length(comparisons))
  cohortComparisonSqls <- lapply(X = indexes, 
                                 function(index)
                                 {
                                   sql <- SqlRender::renderSql("select @index as comparison_id, 
                                                               @targetId as target_id, @comparatorId as comparator_id",
                                                               index = index,
                                                               targetId = comparisons[[index]]$targetId,
                                                               comparatorId = comparisons[[index]]$comparatorId)$sql
                                 })
  
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "createComparisons.sql",
                                           packageName = "CohortComparison", 
                                           dbms = connectionDetails$dbms,
                                           scratchDatabaseSchema = scratchDatabaseSchema,
                                           tablePrefix = tablePrefix,
                                           cohortComparisonSqls <- paste(cohortComparisonSqls, collapse = "\nunion all\n"))
  
  
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  DatabaseConnector::executeSql(connection = connection, sql = sql)
  DatabaseConnector::disconnect(connection = connection)
  
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "generateCovariates.sql",
                                           packageName = "CohortComparison", 
                                           dbms = connectionDetails$dbms,
                                           cdmDatabaseSchema = cdmDatabaseSchema,
                                           scratchDatabaseSchema = scratchDatabaseSchema,
                                           tablePrefix = tablePrefix)
  
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  DatabaseConnector::executeSql(connection = connection, sql = sql)
  DatabaseConnector::disconnect(connection = connection)
}


#' Wrapper for FeatureExtraction to generate covariates of cohort
#'
#' @description                   Wrapper for FeatureExtraction to generate covariates of a T vs C pair
#' @param connectionDetails       The connection details of the database, as generated using \code{createConnectionDetails}
#' @param cdmDatabaseSchema       The fully qualified name of the database schema holding the CDM data
#' @param cdmVersion              The version of the CDM database
#' @param cohortId                The Id of the cohort of interest
#'
#' @export
generateCovariates <- function(connectionDetails, 
                               cdmDatabaseSchema,
                               cdmVersion, 
                               cohortId)
{
  if (!dir.exists("output"))
  {
    dir.create("output")  
  }
  
  fileName <- paste("output", paste(cdmDatabaseSchema, cohortId, sep = "_"), sep = "/")
  if (dir.exists(fileName))
  {
    stop("CovariateData directory exists, stopping.")
  }
  covariateSettings <- FeatureExtraction::createCovariateSettings(
    useDemographicsGender = FALSE,
    useDemographicsAge = FALSE, useDemographicsIndexYear = FALSE,
    useDemographicsIndexMonth = FALSE, useConditionOccurrenceLongTerm = FALSE,
    useConditionOccurrenceShortTerm = FALSE, useConditionEraLongTerm = FALSE,
    useConditionEraShortTerm = FALSE, useConditionGroupEraShortTerm = FALSE,
    useConditionGroupEraLongTerm = FALSE, useDrugExposureLongTerm = FALSE,
    useDrugExposureShortTerm = FALSE, useDrugEraLongTerm = FALSE,
    useDrugEraShortTerm = FALSE, useDrugGroupEraLongTerm = FALSE,
    useDrugGroupEraShortTerm = FALSE, useProcedureOccurrenceLongTerm = FALSE,
    useProcedureOccurrenceShortTerm = FALSE,
    useDeviceExposureLongTerm = FALSE, useDeviceExposureShortTerm = FALSE,
    useMeasurementLongTerm = FALSE, useMeasurementShortTerm = FALSE,
    useObservationLongTerm = FALSE, useObservationShortTerm = FALSE,
    useCharlsonIndex = FALSE, longTermDays = 365, shortTermDays = 30,
    windowEndDays = 0, excludedCovariateConceptIds = c(),
    addDescendantsToExclude = TRUE, includedCovariateConceptIds = c(),
    addDescendantsToInclude = TRUE, includedCovariateIds = c(),
    deleteCovariatesSmallCount = 100
  )
  
  
  # covariateData <- FeatureExtraction::getDbDefaultCovariateData(connection = connection, 
  #                                                               cdmDatabaseSchema = cdmDatabaseSchema,
  #                                                               cdmVersion = cdmVersion,
  #                                                               covariateSettings = covariateSettings)
  covariateData <- FeatureExtraction::getDbCovariateData(connectionDetails = connectionDetails,
                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                        cdmVersion = cdmVersion, cohortIds = c(cohortId),
                                        covariateSettings = covariateSettings, aggregated = FALSE)
  
  FeatureExtraction::saveCovariateData(covariateData = covariateData, file = fileName)
  
}

#' Get Plot Covariates
#' @description              Subsets the full covariate data RDS file
#' @param covariateData      A data frame with covariate data generated by \code{generateCovariates}
#' @return                   A subsetted data frame ready for visualization
#' @export
getPlotCovariates <- function(covariateData)
{
  covariateData <- loadCovariateData(file = "output/ccae/4504")
  metadata <- covariateData$metaData
  merged <- ffbase::merge.ffdf(x = covariateData$covariates, y = covariateData$covariateRef, 
                               by = "covariateId")
  
  subset <- ffbase::subset.ffdf(merged, conceptId != 0)
  
  grp <- ffbase2::grouped_ffdf(data = subset, statValue = sum(as.integer(covariateValue)) / metadata$populationSize)
  # tblConcepts <- ffbase2::tbl_ffdf(data = subset)
  # 
  # 
  # covariateIds <- tblConcepts %>% 
  #                   dplyr::group_by(covariateId, conceptId) %>%
  #                   dplyr::summarise(n())
                    #dplyr::summarize(statValue = sum(as.integer(covariateValue)) / metadata$populationSize)
  
  # %>%
  #   dplyr::summarize(statValue = sum(as.integer(covariateValue)))
                    
  
  
  aggConcepts <- ffbase::ffdfdply(x = concepts, split = as.character.ff(concepts$covariateId), 
                          BATCHBYTES = 5e+8,
                           function(data)
                           {
                             newData <- data.frame(
                               covariateId <- data$covariateId[1],
                               conceptId <- data$conceptId[1],
                               statValue <- length(data$rowId) / metadata$populationSize,
                               stdDev <- sd(data$covariateValue)
                             )
                             newData
                           }
  )
  
  #data$stat_value <- length(data$rowId) / metadata$populationSize
  covariateCounts <- aggregate.data.frame(covariateData$covariates, covariateData$covariates["covariateId"], FUN = "sum")
  return(NULL)
}

#' @export
getMetadata <- function(targetId, comparatorId)
{
  meta <- {}
  meta$xTitle <- getFormattedCohortName(webApiPrefix = Sys.getenv("webApiPrefix"), 
                                        cohortDefinitionId = comparatorId, 
                                        useHttps = as.boolean(Sys.getenv("webApiUseSsl"))[1])
  meta$yTitle <- getFormattedCohortName(webApiPrefix = Sys.getenv("webApiPrefix"), 
                                        cohortDefinitionId = targetId, 
                                        useHttps = as.boolean(Sys.getenv("webApiUseSsl"))[1])
  meta$xTitle <- gsub(pattern = "&", replacement = "and", x = meta$xTitle)
  meta$xTitle <- gsub(pattern = "&gt;", replacement = "and", x = meta$xTitle)
  meta$yTitle <- gsub(pattern = "&", replacement = "and", x = meta$yTitle)
  meta$yTitle <- gsub(pattern = "&gt;", replacement = "and", x = meta$yTitle)
  return (meta)
}

#' @export
getFeatures <- function(targetId, comparatorId)
{
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("cdmDbms"), 
                                                                  server = Sys.getenv("cdmServer"),
                                                                  port = Sys.getenv("cdmServerPort"))
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "getSummaryData.sql", 
                                           packageName = "CohortComparison", 
                                           dbms = connectionDetails$dbms, 
                                           tablePrefix = Sys.getenv("tablePrefix"),
                                           scratchDatabaseSchema = Sys.getenv("scratchDatabaseSchema"),
                                           cdmDatabaseSchema = Sys.getenv("cdmDatabaseSchema"),
                                           targetId = targetId,
                                           comparatorId = comparatorId)
  connection <- connect(connectionDetails)
  data <- DatabaseConnector::querySql(connection = connection, sql = sql)
  DatabaseConnector::disconnect(connection)
  return (data)
}