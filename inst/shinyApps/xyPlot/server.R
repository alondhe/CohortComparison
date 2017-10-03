library(shiny)
library(googleCharts)

# Define server logic required to draw a histogram
shinyServer(function(input, output) {
  
  #33cc33 Conditions (g)
  #99ff66 Procedures (g)
  #003380  Drugs (b)
  #3333cc  Measurement (b)
  #ffcc66 Metadata (y)
  #ffeecc Gender (y)
  #ffaa00 Race (y)
  #b37700 Ethnicity (y)
  
  
  # defaultColors <- c("#3366cc", "#dc3912", "#ff9900", "#ffff00",
  #                    "#109618", "#990099", "#0099c6", "#dd4477")
  # defaultColors <- RColorBrewer::brewer.pal(length(levels(data$DOMAIN_ID)), "Spectral")
  # series <- structure(
  #   lapply(defaultColors, function(color) { list(color=color) }),
  #   names = levels(data$DOMAIN_ID)
  # )
  
  series <- {}
  series$Condition$color <- "#33cc33"
  series$Procedure$color <- "#99ff66"
  series$Drug$color <- "#003380"
  series$Measurement$color <- "#3333cc"
  series$Metadata$color <- "#ffcc66"
  series$Gender$color <- "#ffeecc"
  series$Race$color <- "#ffaa00"
  series$Ethnicity$color <- "#b37700"
  
  output$bubble <- reactive({
    list(
      data = googleDataTable(data),
      options = list(
        series = series
      )
    )
  })
})
