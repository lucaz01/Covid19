# Data taken from here https://github.com/bumbeishvili/covid19-daily-data

#' Data Urls confirmed_timeseries
#' @rdname DataUrls
#'
#' @export
confirmed_timeseries_csv_url <- "https://raw.githubusercontent.com/bumbeishvili/covid19-daily-data/master/time_series_19-covid-Confirmed.csv"

#' Data Urls deaths_timeseries_csv_url
#' @rdname DataUrls
#'
#' @export
deaths_timeseries_csv_url <- "https://raw.githubusercontent.com/bumbeishvili/covid19-daily-data/master/time_series_19-covid-Deaths.csv"

#' Data Urls recovered_timeseries_csv_url
#' @rdname DataUrls
#'
#' @export
recovered_timeseries_csv_url <- "https://raw.githubusercontent.com/bumbeishvili/covid19-daily-data/master/time_series_19-covid-Recovered.csv"

#' Data Urls daily_url
#' @rdname DataUrls
#'
#' @export
daily_url <- "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports/"

#' Get timeseries data
#' @rdname get_timeseries_data
#'
#' @return data list of confirmed, deaths and recovered, each for Province.State, Country.Region, Lat, Long, and day
#'
#' @export
get_timeseries_data <- function() {
  data <- list(
    confirmed = read.csv(file = confirmed_timeseries_csv_url, stringsAsFactors = FALSE),
    deaths = read.csv(file = deaths_timeseries_csv_url, stringsAsFactors = FALSE),
    recovered = read.csv(file = recovered_timeseries_csv_url, stringsAsFactors = FALSE)
  )
}

#' Get daily data
#' @rdname get_daily_data
#'
#' @param date string of format mm-dd-yyyy
#'
#' @return data data.frame
#'
#' @export
get_daily_data <- function(date) {
  data <- read.csv(file = paste0(daily_url, date, ".csv"), stringsAsFactors = FALSE)
}

#' Get timeseries single data
#' @rdname get_timeseries_single_data
#'
#' @param param character string
#'
#' @return data data.frame for Province.State, Country.Region, Lat, Long, and day
#'
#' @export
get_timeseries_single_data <- function(param) {
  data <- read.csv(file = eval(as.symbol(paste0(param,"_timeseries_csv_url"))), stringsAsFactors = FALSE)
}


#' Get timeseries full data
#' @rdname get_timeseries_full_data
#'
#' @return data tibble of confirmed, deaths, active and recovered, each for Province.State, Country.Region, Lat, Long, and day
#'
#' @import dplyr
#' @import tidyr
#'
#' @export
get_timeseries_full_data <- function() {

  convert_date <- function(df){
    df %>%
      mutate(date = gsub("X", "0", date)) %>%
      mutate(date = as.Date(date, format = "%m.%d.%y")) %>%
      arrange(date)
  }

  confirmed <- get_timeseries_single_data("confirmed") %>%
    pivot_longer(cols = starts_with("X"), names_to = "date", values_to = "confirmed") %>%
    convert_date() %>%
    mutate(confirmed = round(confirmed)) # necessary for worldometers data, which is evenly spread across US states
  deaths <- get_timeseries_single_data("deaths")  %>%
    pivot_longer(cols = starts_with("X"), names_to = "date", values_to = "deaths") %>%
    convert_date() %>%
    mutate(deaths = round(deaths)) # necessary for worldometers data, which is evenly spread across US states
  recovered <- get_timeseries_single_data("recovered")  %>%
    pivot_longer(cols = starts_with("X"), names_to = "date", values_to = "recovered") %>%
    convert_date() %>%
    mutate(recovered = round(recovered)) # necessary for worldometers data, which is evenly spread across US states

  join_by_cols <- c("Province.State", "Country.Region", "Lat", "Long", "date")

  data <- confirmed %>%
    left_join(deaths, by = join_by_cols) %>%
    left_join(recovered, by = join_by_cols) %>%
    mutate(active = confirmed - deaths - recovered)
}


#' Get data by day contagion
#' @rdname get_timeseries_by_contagion_day_data
#'
#' @param data data.frame
#'
#' @return data tibble of confirmed, deaths, active and recovered, each for Province.State, Country.Region, Lat, Long, contagion_day and day
#'
#' @import dplyr
#' @import tidyr
#'
#' @export
get_timeseries_by_contagion_day_data <- function(data) {

  data <- data %>%
    arrange(desc(Country.Region), date) %>%
    mutate(no_contagion = case_when(
      confirmed == 0 ~ 1,
      TRUE ~ 0
    )) %>%
    group_by(Province.State, Country.Region, Lat, Long) %>%
    mutate(incremental = seq(1:n())) %>%
    mutate(offset = sum(no_contagion)) %>%
    mutate(tmp = incremental - offset) %>%
    mutate(contagion_day = case_when(
      tmp < 0 ~ 0,
      TRUE ~ tmp
    )) %>%
    select(-incremental, -offset, -no_contagion, -tmp) %>%
    mutate(new_confirmed = confirmed - lag(confirmed)) %>%
    mutate(new_deaths = deaths - lag(deaths)) %>%
    mutate(new_active = active - lag(active)) %>%
    mutate(new_recovered = recovered - lag(recovered)) %>%
    mutate(growth_rate = 100*new_confirmed / lag(confirmed)) %>%
    mutate(death_rate = 100*new_deaths / lag(deaths)) %>%
    mutate_if(is.numeric, function(x){replace_na(x,0)} ) %>%
    mutate_if(is.numeric, function(x){ifelse(x == "Inf",0, x)} ) %>%
    ungroup()
}

#' Global data timeseries
#' @rdname get_timeseries_global_data
#'
#' @param data data.frame
#'
#' @import dplyr
#'
#' @return global tibble of global confirmed, deaths, active and recovered, for each day
#'
#' @export
get_timeseries_global_data <- function(data){
  global <- data %>%
    group_by(date) %>%
    summarize_at(c("confirmed", "deaths", "recovered", "active", "new_confirmed", "new_deaths", "new_active", "new_recovered"), sum) %>%
    mutate(growth_rate = 100*new_confirmed / lag(confirmed)) %>%
    mutate(death_rate = 100*new_deaths / lag(deaths)) %>%
    ungroup()
}

#' Country.Region data timeseries
#' @rdname get_timeseries_country_data
#'
#' @param data data.frame
#' @param country name of the country. Character string
#'
#' @import dplyr
#'
#' @return country_df tibble of by country confirmed, deaths, active and recovered for each day
#'
#' @export
get_timeseries_country_data <- function(data, country){
  country_df <- data %>%
    filter(Country.Region == country) %>%
    group_by(date) %>%
    summarize(confirmed = sum(confirmed), deaths = sum(deaths), recovered = sum(recovered), active = sum(active), new_confirmed = sum(new_confirmed), new_deaths = sum(new_deaths), new_active = sum(new_active), new_recovered = sum(new_recovered), contagion_day = max(contagion_day)) %>%
    mutate(growth_rate = 100*new_confirmed / lag(confirmed)) %>%
    mutate(death_rate = 100*new_deaths / lag(deaths)) %>%
    arrange(desc(date)) %>%
    ungroup()
}

#' Aggregate data by country
#' @rdname aggregate_country_data
#'
#' @param data data.frameing
#'
#' @import dplyr
#'
#' @return country_df tibble of by country confirmed, deaths, active and recovered for each day
#'
#' @export
aggregate_country_data <- function(data){
  country_df <- data %>%
    filter( date == max(date)) %>%
    select(-Province.State, -Lat, -Long) %>%
    group_by(Country.Region) %>%
    summarize(confirmed = sum(confirmed), deaths = sum(deaths), recovered = sum(recovered), active = sum(active), new_confirmed = sum(new_confirmed), new_deaths = sum(new_deaths), new_active = sum(new_active), new_recovered = sum(new_recovered), contagion_day = max(contagion_day)) %>%
    arrange(desc(confirmed)) %>%
    ungroup()
}

#' Aggregate data by province
#' @rdname aggregate_province_timeseries_data
#'
#' @param data data.frameing
#'
#' @import dplyr
#'
#' @return df tibble of by country confirmed, deaths, active and recovered for each day
#'
#' @export
aggregate_province_timeseries_data <- function(data){
  df <- data %>%
    select(-Province.State) %>%
    group_by(Country.Region, date) %>%
    summarize(confirmed = sum(confirmed), deaths = sum(deaths), recovered = sum(recovered), active = sum(active), new_confirmed = sum(new_confirmed), new_deaths = sum(new_deaths), new_active = sum(new_active), new_recovered = sum(new_recovered), contagion_day = max(contagion_day)) %>%
    mutate(growth_rate = 100*new_confirmed / lag(confirmed)) %>%
    mutate(death_rate = 100*new_deaths / lag(deaths)) %>%
    arrange(desc(date)) %>%
    ungroup()
}

#' Province.State data timeseries
#' @rdname get_timeseries_province_data
#'
#' @param data data.frame
#' @param province name of the province Character string
#'
#' @import dplyr
#'
#' @return province_df tibble of by country confirmed, deaths, active and recovered for each day
#'
#' @export
get_timeseries_province_data <- function(data, province){
  province_df <- data %>%
    filter(Province.State == province) %>%
    group_by(date) %>%
    summarize(confirmed = sum(confirmed), deaths = sum(deaths), recovered = sum(recovered), active = sum(active), new_confirmed = sum(new_confirmed), new_deaths = sum(new_deaths), new_active = sum(new_active), new_recovered = sum(new_recovered), contagion_day = max(contagion_day)) %>%
    mutate(growth_rate = 100*new_confirmed / lag(confirmed)) %>%
    mutate(death_rate = 100*new_deaths / lag(deaths)) %>%
    arrange(desc(date)) %>%
    ungroup()
}

#' date data
#' @rdname get_date_data
#'
#' @param data data.frame
#' @param date date format yyyy-mm-dd
#'
#' @import dplyr
#'
#' @return global tibble of confirmed, deaths, active and recovered for each day
#'
#' @export
get_date_data <- function(data, date){
  date_df <- data %>%
    group_by(date) %>%
    summarize(confirmed = sum(confirmed), deaths = sum(deaths), recovered = sum(recovered), active = sum(active), new_confirmed = sum(new_confirmed), new_deaths = sum(new_deaths), new_active = sum(new_active), new_recovered = sum(new_recovered), contagion_day = max(contagion_day)) %>%
    mutate(growth_rate = 100*new_confirmed / lag(confirmed)) %>%
    mutate(death_rate = 100*new_deaths / lag(deaths)) %>%
    ungroup()
}
