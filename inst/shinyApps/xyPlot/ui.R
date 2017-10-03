#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

shinyUI(fluidPage(
  
  googleChartsInit(),
  tags$link(
    href=paste0("http://fonts.googleapis.com/css?",
                "family=Open+Sans:300,600,300italic"),
    rel="stylesheet", type="text/css"),
  tags$style(type="text/css",
             "body {font-family: 'Open Sans'}"
  ),
  
  
  headerPanel(paste0("Cohort Comparison of Standard Features: ", metadata$chartTitle)),
  
  
  mainPanel(
           googleBubbleChart("bubble",
                             width="1200px", height = "800px",
                             options = list(
                               fontName = "Open Sans",
                               fontSize = 13, 
                               # Set axis labels and ranges
                               hAxis = list(
                                 title = metadata$xTitle,
                                 titleTextStyle = list(
                                   fontSize = 20,
                                   italic = FALSE,
                                   bold = TRUE
                                 )
                               ), 
                               vAxis = list(
                                 title = metadata$yTitle,
                                 titleTextStyle = list(
                                   fontSize = 20,
                                   italic = FALSE,
                                   bold = TRUE
                                 )
                               ), 
                               # The default padding is a little too spaced out
                               chartArea = list(
                                 top = 50, left = 75, 
                                 height = "75%", width = "75%"
                               ),
                               # Allow pan/zoom
                               explorer = list(),
                               # Set bubble visual props
                               bubble = list(
                                 textStyle = list(
                                   color = "none"
                                 )
                               ),
                               # Set fonts
                               titleTextStyle = list(
                                 fontSize = 16
                               ),
                               tooltip = list(
                                 textStyle = list(
                                   fontSize = 12
                                 )
                               )
                             )
    )
  )))
