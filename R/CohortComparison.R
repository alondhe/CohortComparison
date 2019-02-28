
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

#' Creates a data frame summarizing the cohort comparison
#' 
#' @param dataFolder        The path to the folder containing data files produced by \code{\link{getChartData}}
#' @param comparisonsPath   The path to the CSV file with the comparisons
#' @param baseUrl           The base URL of the WebAPI instance
#' 
#' @export
getSummaryTable <- function(dataFolder,
                            comparisonsPath,
                            baseUrl) {
  
  comparisons <- read.csv(file = comparisonsPath, header = TRUE, as.is = TRUE, stringsAsFactors = FALSE)
  tables <- apply(comparisons, 1, function(t) {
    
    df <- readRDS(file.path(dataFolder, sprintf("%s_vs_%s.rds", t["TARGET_ID"][[1]], t["COMPARATOR_ID"][[1]])))
    
    numCovariates <- nrow(df)
    numUnbalancedCovs <- nrow(df[df$ABS_STANDARD_DIFF > 0.1,])
    perUnbalancedCovariates <- 100.00 * (numUnbalancedCovs / numCovariates)
    
    data.frame(
      outcome = t["OUTCOME_NAME"][[1]],
      targetCohort = OhdsiRTools::getCohortDefinitionName(baseUrl = baseUrl, definitionId = as.integer(t["TARGET_ID"][[1]]), formatName = TRUE),
      comparatorCohort = OhdsiRTools::getCohortDefinitionName(baseUrl = baseUrl, definitionId = as.integer(t["COMPARATOR_ID"][[1]]), formatName = TRUE),
      numCovariates = numCovariates,
      numUnbalancedCovs = numUnbalancedCovs,
      perUnbalancedCovariates = perUnbalancedCovariates
    )
  })
  
  do.call(rbind, tables)
}


