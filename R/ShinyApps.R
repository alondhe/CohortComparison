#' Launch the XY Plot Shiny app
#' 
#' @param launch.browser    Should the app be launched in your default browser, or in a Shiny window.
#'                          Note: copying to clipboard will not work in a Shiny window.
#' 
#' @details 
#' Launches a Shiny app that allows the viewing of covariate SMDs between T and C in an X-Y plot.
#' 
#' @export
launchXyPlot <- function(launch.browser = TRUE)
{
  ensure_installed("shinydashboard")
  appDir <- system.file("shinyApps", "xyPlot", package = "CohortComparison")
  shiny::runApp(appDir, display.mode = "normal", launch.browser = launch.browser)
}


# Borrowed from devtools: https://github.com/hadley/devtools/blob/ba7a5a4abd8258c52cb156e7b26bb4bf47a79f0b/R/utils.r#L44
is_installed <- function (pkg, version = 0)
{
  installed_version <- tryCatch(utils::packageVersion(pkg), 
                                error = function(e) NA)
  !is.na(installed_version) && installed_version >= version
}

# Borrowed and adapted from devtools: https://github.com/hadley/devtools/blob/ba7a5a4abd8258c52cb156e7b26bb4bf47a79f0b/R/utils.r#L74
ensure_installed <- function(pkg)
{
  if (!is_installed(pkg)) {
    msg <- paste0(sQuote(pkg), " must be installed for this functionality.")
    if (interactive()) {
      message(msg, "\nWould you like to install it?")
      if (menu(c("Yes", "No")) == 1) {
        install.packages(pkg)
      } else {
        stop(msg, call. = FALSE)
      }
    } else {
      stop(msg, call. = FALSE)
    }
  }
}