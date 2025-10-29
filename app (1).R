library(shiny)
library(dplyr)
library(ggplot2)

# Load the datasets

present_energy_data <- read.csv("final_dataset_less_columns.csv")
future_energy_data <- read.csv("future_predictions_LM 2.csv")


# making sure date column is in date format
present_energy_data$date <- as.Date(present_energy_data$date)
future_energy_data$date <- as.Date(future_energy_data$date)

#Defining UI
ui <- fluidPage(
  titlePanel("Energy Usage Comparison"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("selected_county", "Select County ID", 
                  choices = c("All Counties", unique(present_energy_data$in.county))),
      actionButton("plot_energy", "Plot Energy Usage Comparison")
    ),
    
    mainPanel(
      plotOutput("energy_plot"),
      h4("Highest Peak Energy"),
      textOutput("highest_peak_present"),
      textOutput("highest_peak_future")
    )
  )
)

#Defining server logic
server <- function(input, output) {
  observeEvent(input$plot_energy, {
    selected_county <- input$selected_county
    
    # Filter and aggregate data for the selected county
    if (selected_county == "All Counties") {
      present_data_filtered <- present_energy_data %>%
        group_by(date) %>%
        summarise(total_energy = sum(total_energy_usage)) %>%
        mutate(Year = "Present")
      
      future_data_filtered <- future_energy_data %>%
        group_by(date) %>%
        summarise(total_energy = sum(predicted_energy)) %>%
        mutate(Year = "Future")
    } else {
      present_data_filtered <- present_energy_data %>%
        filter(in.county == selected_county) %>%
        group_by(date) %>%
        summarise(total_energy = sum(total_energy_usage)) %>%
        mutate(Year = "Present")
      
      future_data_filtered <- future_energy_data %>%
        filter(in.county == selected_county) %>%
        group_by(date) %>%
        summarise(total_energy = sum(predicted_energy)) %>%
        mutate(Year = "Future")
    }
    
    #Combine  datasets
    combined_data <- bind_rows(present_data_filtered, future_data_filtered)
    
    #peak energy usage
    peak_present <- present_data_filtered[which.max(present_data_filtered$total_energy), ]
    peak_future <- future_data_filtered[which.max(future_data_filtered$total_energy), ]
    
    #plot
    output$energy_plot <- renderPlot({
      ggplot(combined_data, aes(x = date, y = total_energy, color = Year, group = Year)) +
        geom_line() +
        geom_point(size = 2) +
        scale_color_manual(values = c("Present" = "blue", "Future" = "red")) +
        theme_minimal() +
        labs(
          title = "Energy Consumption Comparison",
          subtitle = "Present Year vs Future Predictions",
          x = "Date",
          y = "Total Energy Consumption (kWh)",
          color = "Year"
        )
    })
    
    #peak energy usage
    output$highest_peak_present <- renderText({
      paste("Present: ", round(peak_present$total_energy, 2), "kWh on", format(peak_present$date, "%d %b"))
    })
    
    output$highest_peak_future <- renderText({
      paste("Future: ", round(peak_future$total_energy, 2), "kWh on", format(peak_future$date, "%d %b"))
    })
  })
}

#Running the application
shinyApp(ui = ui, server = server)