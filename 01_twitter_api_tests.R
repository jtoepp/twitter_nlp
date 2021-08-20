# TWITTER API TESTS----

# LIBRARIES ----
# Load libraries
# specify the packages of interest
packages = c(
    # Work Horses
    "dplyr"
    
    # Twitter API
    , "rtweet"    

    # Interactive Maps
    , "tmaptools"
    , "leaflet"   

    # Core
    , "tidyverse"
)

# use this function to check if each package is on the local machine
# if a package is installed, it will be loaded
# if any are not, the missing package(s) will be installed and loaded
package.check <- lapply(packages, FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
        install.packages(x, dependencies = TRUE)
        library(x, character.only = TRUE)
    }
})

source("scripts/geocode_for_free.R") # geocoding script


# 1.0 ACCOUNT SETUP -----

# Twitter Developer Account and App Setup
# Follow these Instructions: https://rtweet.info/articles/auth.html

token <- create_token(
    
    # Replace with your Twitter app name
    app             = "rtweets_api_con", 
    
    # Replace with your App API Key 
    consumer_key    = config::get("twitter-api-key", file = "../config.yml"), 
    
    # Replace with your App Secret Key
    consumer_secret = config::get("twitter-secret", file = "../config.yml") 
)


# 2.0 SEARCH TWEETS ----
# - Poll tweet history that has happened over n-tweets

# 2.1 search_tweets()
rtweet::search_tweets(
    q = "#covid19",      # Search query
    n = 100,             # Number of results
    lang = "en",         # Language
    include_rts = FALSE  # Don't include retweets if want unique tweets
)

# tweets_covid %>% write_rds(path = "data/tweets_covid.rds")

# 2000 Tweets related to COVID, Downloaded on April 6, 2020
tweets_covid <- read_rds("data/tweets_covid.rds")


# 2.2 Results 

tweets_covid %>% glimpse()

# User info
tweets_covid %>% slice(1:5) %>% select(screen_name, location, description)

# Tweet info
tweets_covid %>% slice(1:5) %>% select(text, url)

# Hastags info
tweets_covid %>% slice(1:5) %>% select(hashtags) %>% unnest_wider(hashtags)

# URL's in the Tweet
tweets_covid %>% slice(1:5) %>% select(urls_expanded_url) %>% unnest(urls_expanded_url)


# 3.0 STREAM TWEETS ----
# - Real-time twitter action 

rt <- stream_tweets(timeout = 5)

rt %>% glimpse()




# 4.0 GEOCODING FILTERS ----

# 4.1 Geocoding - GO from text to location

# Geocoding Coordinates
lookup_coords("london, uk") # Requires Google Maps API (Costs)
lookup_coords("usa") # Pre-programmed

# BONUS #1 - Free Geocoding Function
geocode_for_free("london, uk") 
geocode_for_free("usa")

# 4.2 Apply to streaming tweets
rt <- stream_tweets(geocode_for_free("london, uk"), timeout = 5)
rt

rt %>% glimpse()


# 4.3 Apply to search tweets

st <- search_tweets(
    q = "#covid19", 
    n = 300, 
    include_rts = FALSE, 
    lang = "en",
    geocode = geocode_for_free("london, uk") %>% near_geocode(100)
)

st %>% glimpse()

st %>%
    select(contains("coords")) %>%
    unnest_wider(geo_coords) %>%
    filter(!is.na(...1))

# CHECK OUT THE OTHER rtweet FUNCTIONALITY:
# https://rtweet.info/articles/intro.html

# 5.0 MAP ----

# 5.1 Intro to Leaflet
?leaflet()

quakes[1:20,] %>%
    leaflet() %>% 
    addTiles() %>%
    addMarkers(~long, ~lat, popup = ~as.character(mag), label = ~as.character(mag))

# 5.2 Mapping our Tweets

st %>%
    select(screen_name, text, coords_coords) %>%
    unnest_wider(coords_coords) %>%
    filter(!is.na(...1)) %>%
    set_names(c("screen_name", "text", "lon", "lat")) %>%
    leaflet() %>%
    addTiles() %>%
    addMarkers(~lon, ~lat, popup = ~as.character(text), label = ~as.character(screen_name))

# 5.3 New Idea - Use a Circle to indicate location of tweets

data_prepared <- tibble(
    location = geocode_for_free("london, uk") %>% near_geocode(100)
) %>%
    separate(location, into = c("lat", "lon", "distance"), sep = ",", remove = FALSE) %>%
    mutate(distance = distance %>% str_remove_all("[^0-9.-]")) %>%
    mutate_at(.vars = vars(-location), as.numeric) 

data_prepared %>%
    leaflet() %>%
    setView(data_prepared$lon, data_prepared$lat, zoom = 3) %>%
    addTiles() %>%
    addMarkers(~lon, ~lat, popup = ~as.character(location), label = ~as.character(location)) %>%
    addCircles(lng = ~lon, lat = ~lat, weight = 1, radius = ~distance/0.000621371)
