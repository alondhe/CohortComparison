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
  
  
  headerPanel("Cohort Comparison of Features"),
  
  mainPanel(
           googleBubbleChart("bubble",
                             width="800px", height = "475px",
                             options = list(
                               fontName = "Open Sans",
                               fontSize = 13, 
                               # Set axis labels and ranges
                               hAxis = list(
                                 title = "Comparator: [OS] Crohns Dx and CRP measurement > 0"
                               ), 
                               vAxis = list(
                                 title = "Target: [OS] Crohns Dx"
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
