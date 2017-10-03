
#' @export
plotlyXy <- function(data, targetId, comparatorId, cdmDbName, title)
{
  pal <- c("#e0f3f8", "#ff5c33", "#fc8d59", "#1b7837", "#9c38ad", "#e5e365", "#4575b4")
  pal <- setNames(pal, c("Balanced", "Measurement", "Race", "Drug", "Condition", "Metadata", "Procedure"))
  p <- plot_ly(data = data, x = ~COMPARATOR_STAT_VALUE, y = ~TARGET_STAT_VALUE, 
               color = ~DOMAIN_ID, colors = pal, type = "scatter", 
               mode = "markers", marker = list(size =10, 
                                               line = list(color = "#000000", width = 1))) %>%
    layout(title = title, shapes = list(type = "line", x0 = 0, x1 = 1, y0 = 0, y1 = 1),
           xaxis = list(title = paste0("Covariate Prevalance: ", 
                                       OhdsiRTools::getCohortDefinitionName(baseUrl = Sys.getenv("webApiPrefix"),
                                                                            definitionId = comparatorId, 
                                                                            formatName = TRUE))), 
           yaxis = list(title = paste0("Covariate Prevalance: ", 
                                       OhdsiRTools::getCohortDefinitionName(baseUrl = Sys.getenv("webApiPrefix"),
                                                                            definitionId = targetId, 
                                                                            formatName = TRUE))))
  
  filePath <- file.path("output", "charts", cdmDbName)
  if (!dir.exists(filePath))
  {
    dir.create(path = filePath, recursive = TRUE)
  }
  export(p, file = file.path(filePath, 
                             paste(
                               paste(targetId, "vs", comparatorId, sep = " "), "png", 
                               sep = ".")
                             ))
}


