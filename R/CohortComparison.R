
#' Get Chart Data
#'
#' @details This function can be used to save chart data for
#'          use in the plotly chart
#' 
#' @param connectionDetails          A connectionDetails object created using \code{createConnectionDetails}
#' @param tablePrefix                The prefix of the scratch tables
#' @param cdmDatabaseSchema          The fully qualified schema name of the CDM database schema
#' @param resultsDatabaseSchema      The fully qualified schema name of the results database schema
#' @param scratchDatabaseSchema      The fully qualified schema name of the scratch database schema
#' @param cohortDf                   A data frame with COMPARISON_ID, TARGET_ID, COMPARATOR_ID,
#'                                   and COMPARISON_NAME
#' 
#' @export
getChartData <- function(connectionDetails, 
                         tablePrefix, 
                         cdmDatabaseSchema,
                         resultsDatabaseSchema,
                         scratchDatabaseSchema,
                         cohortDf) {
  
  comparisons <- apply(X = cohortDf, MARGIN = 1, function(row) {
    sprintf("select %1d as comparison_id, %2d as target_id, %3d as comparator_id",
            as.integer(row["COMPARISON_ID"]),
            as.integer(row["TARGET_ID"]),
            as.integer(row["COMPARATOR_ID"]))
  })
  
  dataTypes <- c("Prevalence") #, "Distributed")
  
  connection <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  dfs <- lapply(dataTypes, function(dataType) {
    sql <- SqlRender::loadRenderTranslateSql(sqlFilename = sprintf("get%sStats.sql", dataType), 
                                             packageName = "CohortComparison", 
                                             dbms = connectionDetails$dbms, 
                                             comparisons = comparisons,
                                             cdmDatabaseSchema = cdmDatabaseSchema,
                                             resultsDatabaseSchema = resultsDatabaseSchema)
    
    data <- DatabaseConnector::querySql(connection = connection, sql = sql)
    data$ABS_STANDARD_DIFF <- 0
    
    if (dataType == "Prevalence") {
      data$ABS_STANDARD_DIFF[(!is.null(data$TARGET_STAT_VALUE) & data$TARGET_STAT_VALUE < 1) |
                               (!is.null(data$COMPARATOR_STAT_VALUE & data$COMPARATOR_STAT_VALUE < 1))] <- abs((data$TARGET_STAT_VALUE - data$COMPARATOR_STAT_VALUE) / 
                                      sqrt((data$TARGET_STAT_VALUE*(1-data$TARGET_STAT_VALUE) + 
                                              data$COMPARATOR_STAT_VALUE*(1-data$COMPARATOR_STAT_VALUE))/2))
    } else {
      data$ABS_STANDARD_DIFF[abs(data$TARGET_STDEV_VALUE + data$COMPARATOR_STDEV_VALUE) > 0] <-
        (data$TARGET_STAT_VALUE - data$COMPARATOR_STAT_VALUE) / sqrt((data$TARGET_STDEV_VALUE + data$COMPARATOR_STDEV_VALUE)/2)
    }
    
    data$DOMAIN_ID[data$ABS_STANDARD_DIFF < 0.1] <- "Balanced"
    data
  })
  
  DatabaseConnector::disconnect(connection = connection)
  data <- do.call("rbind", dfs)

  return (data)
}

#' Plot the Cohort Comparison chart using Plotly
#' 
#' @param data            A data frame created by \code{getChartData}
#' @param targetId        The cohort definition id of the target cohort
#' @param comparatorId    The cohort definition id of the comparator cohort
#' @param targetName      The name of the target cohort
#' @param comparatorName  The name of the comparator cohort
#' @param cdmDbName       The name of the CDM data source
#' @param title           The title of the chart
#' @param baseUrl         The base URL of the WebAPI instance
#' 
#' @export
plotlyXy <- function(data, 
                     targetId, 
                     comparatorId,
                     targetName,
                     comparatorName,
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
  
  p <- plotly::plot_ly(data = data, x = ~COMPARATOR_STAT_VALUE, y = ~TARGET_STAT_VALUE, 
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
  
  filePath <- file.path("output", "charts", cdmDbName)
  if (!dir.exists(filePath)) {
    dir.create(path = filePath, recursive = TRUE)
  }
  plotly::export(p, file = file.path(filePath, sprintf("%1d vs %2d.png", targetId, comparatorId)))
}


#' Import Features From WebAPI
#' 
#' @param baseUrl      The URL of the WebAPI endpoint
#' @param cohortId     The cohort definition id in Atlas
#' @param sourceKey    The source key for the CDM as defined in Atlas
#' 
#' @return             A list of data frames (one for distributed features, one for prevalence features),
#'                     with name and df as attributes
#' 
#' @export
#' 
importFeaturesFromWebApi <- function(baseUrl, 
                                     cohortId,
                                     sourceKey) {
  distributionUrl <- sprintf("%1s/featureextraction/query/distributions/%1d/%2s",
                             baseUrl,
                             cohortId,
                             sourceKey)
  
  prevalenceUrl <- sprintf("%1s/featureextraction/query/prevalence/%1d/%2s",
                           baseUrl,
                           cohortId,
                           sourceKey)
  
  dfs <- lapply(c("distribution", "prevalence"), function (type) {
    url <- get(sprintf("%sUrl", type))
    json <- httr::GET(url)
    json <- httr::content(json)
    list(name = type, df = do.call(rbind, lapply(json, data.frame)))
  })
  
  return (dfs)
}
