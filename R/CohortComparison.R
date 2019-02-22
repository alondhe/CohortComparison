
#' Get Chart Data
#'
#' @details This function can be used to save chart data for
#'          use in the plotly chart
#' 
#' @param connectionDetails          A connectionDetails object created using \code{createConnectionDetails}
#' @param vocabDatabaseSchema        The fully qualified schema name of the CDM database schema
#' @param resultsDatabaseSchema      The fully qualified schema name of the results database schema
#' @param generationId               The ID of the Cohort Characterization generation from Atlas
#' @param targetCohortId             The ID of the target cohort as defined in Atlas
#' @param comparatorCohortId         The ID of the comparator cohort as defined in Atlas
#' @param outputFolder               A folder to store the chart data RDS files
#' 
#' @export
getChartData <- function(connectionDetails,
                         vocabDatabaseSchema,
                         resultsDatabaseSchema,
                         generationId,
                         targetCohortId,
                         comparatorCohortId,
                         outputFolder = "output") {

  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection = connection))

  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "getPrevalenceStats.sql", 
                                           packageName = "CohortComparison", 
                                           dbms = connectionDetails$dbms, 
                                           vocabDatabaseSchema = vocabDatabaseSchema,
                                           resultsDatabaseSchema = resultsDatabaseSchema,
                                           generationId = generationId,
                                           targetCohortId = targetCohortId, 
                                           comparatorCohortId = comparatorCohortId)
  
  data <- DatabaseConnector::querySql(connection = connection, sql = sql)
  data$ABS_STANDARD_DIFF <- 0
    
  data$ABS_STANDARD_DIFF[(!is.null(data$TARGET_STAT_VALUE) & data$TARGET_STAT_VALUE < 1) |
                           (!is.null(data$COMPARATOR_STAT_VALUE & data$COMPARATOR_STAT_VALUE < 1))] <- abs((data$TARGET_STAT_VALUE - data$COMPARATOR_STAT_VALUE) / 
                                  sqrt((data$TARGET_STAT_VALUE*(1-data$TARGET_STAT_VALUE) + 
                                          data$COMPARATOR_STAT_VALUE*(1-data$COMPARATOR_STAT_VALUE))/2))
  
  data$DOMAIN_ID[data$ABS_STANDARD_DIFF < 0.1] <- "Balanced"
  rdsFile <- file.path(outputFolder, sprintf("%1d_vs_%2d.rds",
                                             targetCohortId,
                                             comparatorCohortId))

  saveRDS(object = data, file = rdsFile)
}

#' Plot the Cohort Comparison chart using Plotly
#' 
#' @param data            A data frame created by \code{getChartData}
#' @param targetId        The cohort definition id of the target cohort
#' @param comparatorId    The cohort definition id of the comparator cohort
#' @param targetName      The name of the target cohort
#' @param comparatorName  The name of the comparator cohort
#' @param outputFolder    The folder to store the charts
#' @param cdmDbName       The name of the CDM database
#' @param title           The title of the chart
#' @param baseUrl         The base URL of the WebAPI instance
#' 
#' @export
plotlyXy <- function(data, 
                     targetId, 
                     comparatorId,
                     targetName,
                     comparatorName,
                     outputFolder, 
                     cdmDbName,
                     title,
                     baseUrl) {
  
  globalFont <- list(family = "arial")
  
  domains <- c("Balanced", "Measurement", "Race", "Drug",
               "Condition", "Metadata", "Procedure", "Device", 
               "Observation", "Ethnicity", "Gender", "Risk Scores")
  
  data <- data[data$DOMAIN_ID %in% domains,]
  
  pal <- c("#e0f3f8", "#ff5c33", "#fc8d59", "#1b7837", 
           "#9c38ad", "#e5e365", "#4575b4", "#878566", 
           "#ffbcec", "#f442dc", "#ff0000", "#011d49")
  pal <- setNames(pal, domains)
  
  p <- plotly::plot_ly(data = data, x = ~COMPARATOR_STAT_VALUE, y = ~TARGET_STAT_VALUE, text = ~COVARIATE_NAME,
                       color = ~DOMAIN_ID, colors = pal, type = "scatter", 
                       mode = "markers", marker = list(size =10, 
                                                       line = list(color = "#000000", width = 1))) %>%
    plotly::layout(font = globalFont,
                   margin = list(l = 100, r = 50, t = 80, b = 100),
                   title = sprintf("(%1s) %2s", cdmDbName, title), 
                   shapes = list(type = "line", x0 = 0, x1 = 1, y0 = 0, y1 = 1), 
                   titlefont = list(size = 24),
                   legend = list(font = list(size = 20)),
                   xaxis = list(titlefont = list(size = 22), 
                                tickfont = list(size = 20),
                                title = comparatorName), 
                   yaxis = list(titlefont = list(size = 22), 
                                tickfont = list(size = 20),
                                title = targetName))
  
  chartPath <- file.path(outputFolder, cdmDbName)
  if (!dir.exists(chartPath)) {
    dir.create(path = chartPath, recursive = TRUE)
  }
  plotly::export(p, file = file.path(chartPath, sprintf("%1d vs %2d.png", targetId, comparatorId)))
  
  p
}


.getMoreStats <- function(data) {
  totalComparisons <- nrow(data)
  totalBalanced <- nrow(subset(data, DOMAIN_ID == 'Balanced'))
  nCondition <- nrow(subset(data,DOMAIN == 'Condition'))
  nDrug <- nrow(subset(data,DOMAIN == 'Drug'))
  nDevice <- nrow(subset(data,DOMAIN == 'Device'))
  nMeasurement <- nrow(subset(data,DOMAIN == 'Measurement'))
  nMetadata <- nrow(subset(data,DOMAIN == 'Metadata'))
  nObservation <- nrow(subset(data,DOMAIN == 'Observation'))
  nProcedure <- nrow(subset(data,DOMAIN == 'Procedure'))
  nRace <- nrow(subset(data,DOMAIN == 'Race'))
  nEthnicity <- nrow(subset(data,DOMAIN == 'Ethnicity'))
  nGender <- nrow(subset(data,DOMAIN == 'Gender'))
  nMeasValue <- nrow(subset(data, DOMAIN =='Meas Value'))
  nTypeConcept <- nrow(subset(data, DOMAIN =='Type Concept'))
  
  nOOBCondition <- nrow(subset(data,DOMAIN == 'Condition' & ABS_STANDARD_DIFF > abs(0.1)))
  nOOBDrug <- nrow(subset(data,DOMAIN == 'Drug' & ABS_STANDARD_DIFF > abs(0.1)))
  nOOBDevice <- nrow(subset(data,DOMAIN == 'Device'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBMeasurement <- nrow(subset(data,DOMAIN == 'Measurement'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBMetadata <- nrow(subset(data,DOMAIN == 'Metadata'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBObservation <- nrow(subset(data,DOMAIN == 'Observation'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBProcedure <- nrow(subset(data,DOMAIN == 'Procedure'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBRace <- nrow(subset(data,DOMAIN == 'Race'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBEthnicity <- nrow(subset(data,DOMAIN == 'Ethnicity'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBGender <- nrow(subset(data,DOMAIN == 'Gender'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBMeasValue <- nrow(subset(data, DOMAIN =='Meas Value'& ABS_STANDARD_DIFF > abs(0.1)))
  nOOBTypeConcept <- nrow(subset(data, DOMAIN =='Type Concept'& ABS_STANDARD_DIFF > abs(0.1)))
  
  nOOB <- nOOBCondition + nOOBDrug + nOOBDevice + nOOBMeasurement + nOOBMetadata + nOOBObservation + nOOBProcedure + nOOBRace + nOOBEthnicity + nOOBGender + 
    nOOBMeasValue + nOOBTypeConcept
  
  
  covarCnts <- data.frame(comparison = comparison$COMPARISON_NAME, target_id = comparison$TARGET_ID, comparator_id = comparison$COMPARATOR_ID, 
                          totalComparisons = totalComparisons, totalBalanced = totalBalanced, nCondition = nCondition, nDrug = nDrug, nDevice=nDevice, nMeasurement = nMeasurement, 
                          nMetadata = nMetadata, nObservation = nObservation, nProcedure=nProcedure, nRace=nRace, nEthnicity = nEthnicity, nGender = nGender,
                          nMeasValue = nMeasValue, nTypeConcept = nTypeConcept, nOOB = nOOB, nOOBCondition = nOOBCondition, nOOBDevice = nOOBDevice, 
                          nOOBDrug = nOOBDrug, nOOBEthnicity = nOOBEthnicity, nOOBGender = nOOBGender, nOOBMeasurement = nOOBMeasurement, 
                          nOOBMetadata = nOOBMetadata, nOOBObservation = nOOBObservation, nOOBProcedure = nOOBProcedure, nOOBRace = nOOBRace)
}