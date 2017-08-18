#' @author                       Ajit Londhe, Jamie Weaver
#' @title                        Get Formatted Cohort Name
#' @details                      Gets a formatted name for a cohort
#' @param webApiPrefix           The URL prefix of the WebAPI instance
#' @param cohortDefinitionId     The cohort definition Id
#' @param useHttps               Should SSL be used?
#' @return                       A string with the formatted cohort name
#' 
#' @export
getFormattedCohortName <- function(webApiPrefix, cohortDefinitionId, useHttps = FALSE) 
{
  return(str_replace_all(str_replace_all(str_replace_all(
    getCohortDefName(webApiPrefix, cohortDefinitionId, useHttps), " ", "_"), 
    "\\[(.*?)\\]_", ""), "_", " "))
}

#' @author                      Ajit Londhe, Jamie Weaver
#' @title                       Get Cohort Definition Name
#' @details                     Obtains the name of a cohort
#' @param webApiPrefix          The URL for WebAPI
#' @param cohortDefinitionId    The concept set id in Atlas
#' @param useHttps              Should SSL be used?
#' @return                      The verbatim name of the cohort
#' @export
getCohortDefName <- function(webApiPrefix, cohortDefinitionId, useHttps = FALSE)
{
  port <- 8080
  protocol <- "http"
  if (useHttps)
  {
    port <- 8443
    protocol <- "https"
  }
  url <- SqlRender::renderSql("@protocol://@webApiPrefix:@port/WebAPI/cohortdefinition/@cohortDefinitionId",
                              protocol = protocol,
                              port = port,
                              webApiPrefix = webApiPrefix,
                              cohortDefinitionId = cohortDefinitionId)$sql
  
  if (useHttps)
  {
    json <- fromJSON(RCurl::getURL(url, .opts = list(ssl.verifypeer = FALSE)))
  }
  else
  {
    req <- GET(url)
    stop_for_status(req)
    json <- fromJSON(content(req, "text"))
  }
  return(json$name)
}