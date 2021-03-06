% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/CohortComparison.R
\name{plotlyXy}
\alias{plotlyXy}
\title{Plot the Cohort Comparison chart using Plotly}
\usage{
plotlyXy(data, targetId, comparatorId, targetName, comparatorName,
  outputFolder, cdmDbName, title, baseUrl)
}
\arguments{
\item{data}{A data frame created by \code{getChartData}}

\item{targetId}{The cohort definition id of the target cohort}

\item{comparatorId}{The cohort definition id of the comparator cohort}

\item{targetName}{The name of the target cohort}

\item{comparatorName}{The name of the comparator cohort}

\item{outputFolder}{The folder to store the charts}

\item{cdmDbName}{The name of the CDM database}

\item{title}{The title of the chart}

\item{baseUrl}{The base URL of the WebAPI instance}
}
\description{
Plot the Cohort Comparison chart using Plotly
}
