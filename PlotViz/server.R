library(shiny)
library(googleCharts)

# Define server logic required to draw a histogram
shinyServer(function(input, output) {
  
  defaultColors <- c("#3366cc", "#dc3912", "#ff9900", "#109618", "#990099", "#0099c6", "#dd4477")
  series <- structure(
    lapply(defaultColors, function(color) { list(color=color) }),
    names = levels(data$DOMAIN_ID)
  )
  
  output$bubble <- reactive({
    list(
      data = googleDataTable(data),
      options = list(
        title = sprintf(
          "Cohort Comparison"),
        series = series
      )
    )
  })
})
