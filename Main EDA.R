# Import the necessary libraries

libs <- c("ggplot2", "dplyr", "readr", "magrittr", "jsonlite")
lapply(libs, require, character.only = TRUE)

# Import the data sets
tmdb <- read.csv("tmdb_5000_movies.csv")

kg <- read.csv("Kaggle_movies.csv")

# The tmdb_credits data frame contains movie_id, title, cast, and crew columns.
# The cast and crew columns are dictionaries containing multiple entries.
# They can be considered datasets on their own.
# The tmdb_credits data frame on the other hand has a lots of different columns
# mostly in a structured format. Some of the variables like keywords contain
# multiple values in a dictionary like structure

# The movies data set is just beauty to the eye

# Start the EDA process
colnames(tmdb)
colnames(kg)
colSums(is.na(kg))


# Let's start our analysis from the consumer side. How have the genre distributions changed
# over time. It is probably shaped according to the viewers.

# kg %>% group_by(year, genre) %>% 
#   summarize(count = n(),
#             prop = n()) %>% 
#   ggplot(aes(x=year, y = prop)) +
#   geom_line()


genre_counts <- kg %>%
  group_by(year, genre) %>%
  summarize(count = n(), .groups = 'drop')

# Calculate the total number of movies per year
yearly_counts <- genre_counts %>%
  group_by(year) %>%
  summarize(total = sum(count), .groups = 'drop')

# Merge the two datasets and calculate the proportion
genre_proportions <- genre_counts %>%
  left_join(yearly_counts, by = "year") %>%
  mutate(proportion = count / total) %>%
  select(year, genre, proportion)

genre_proportions %>% 
  ggplot(aes(x = year, y = proportion, color = genre)) +
  geom_line() +
  labs(title = "Proportion of Movie Genres Over Time", 
       x = "Year", 
       y = "Proportion") +
  scale_fill_brewer(palette = "Set1")+
  theme_minimal()



# There are some genres which are very rare. Get rid of them
per_year_movie_counts <- genre_counts %>% group_by(genre) %>% 
  summarize(mean_count_per_year = mean(count, na.rm = T)) %>% 
  arrange(desc(mean_count_per_year)) # Take the genres that have an average of more than 5

genres_of_interest <- per_year_movie_counts %>% 
  filter(mean_count_per_year > 5) %>% 
  pull(genre)

# Visualization for these genres
# Line Plot
genre_proportions %>% 
  filter(genre %in% genres_of_interest) %>% 
  ggplot(aes(x=year, y = proportion, color = genre)) +
  geom_line(linewidth = 1.2) +
  labs(title = "Proportion of Movie Genres Over Time")
  theme_light()

# Stacked Area Plot
genre_proportions %>% 
  filter(genre %in% genres_of_interest) %>% 
  ggplot(aes(x=year, y = proportion, fill = genre)) +
  geom_area(linewidth = 1.6) +
  labs("Proportion of Movie Genres Over Time") +
  scale_fill_brewer(palette = "Set1") +
  theme_light()

# Faceted Area Plot
genre_proportions %>% 
  filter(genre %in% genres_of_interest) %>% 
  ggplot(aes(x=year, y = proportion, fill = genre)) +
  geom_area(linewidth = 1.6) +
  theme_light() +
  facet_wrap(~genre)

# It seems interesting...


# 1.2- Are the genre distributions different across regions?
# create a region column to group countries to based on regions
eu_countries <- c("Austria", "Belgium", "Bulgaria", "Czech Republic", "Denmark", "Finland", "France", "Georgia", "Greece", "Germany",
                  "Hungary", "Iceland", "Ireland", "Italy", "Malta", "Netherlands", "Norway", "Poland", "Portugal",
                  "Republic of Macedonia", "Romania", "Slovakia", "Slovenia", "Spain", "Sweden", "Switzerland", "Turkey",
                  "United Kingdom", "West Germany", "Yugoslavia")

others <- c("Afghanistan", "Australia", "Bahamas", "Cambodia", "Cameroon", "Canada", "Chile", "China", "Colombia",
            "Dominican Republic", "Egypt", "Hong Kong", "India", "Indonesia", "Iran", "Israel", "Japan", "Kenya")

kg <- kg[kg$country != "", ]

kg <- kg %>% mutate(
  region = case_when(
    country %in% eu_countries ~ "Europe",
    country == "United States" ~ "USA",
    T ~ "Others"
  )
)

table(kg$region)

# To construct a side-by-side bar chart, extract the distributions 
# Filter only Action, Drama, Comedy, Horror, Animation
acdh_genres <- c("Action", "Drama", "Comedy", "Horror", "Animation")

usa_grp <- kg %>% 
  filter(genre %in% acdh_genres & region == "USA") %>% 
  group_by(region, genre) %>% 
  summarize(prop = n() / table(kg$region)[3],
            count = n())

eu_grp <- kg %>% 
  filter(genre %in% acdh_genres & region == "Europe") %>% 
  group_by(region, genre) %>% 
  summarize(prop = n() / table(kg$region)[1],
            count = n())

others_grp <- kg %>% 
  filter(genre %in% acdh_genres & region == "Others") %>% 
  group_by(region, genre) %>% 
  summarize(prop = n() / table(kg$region)[2],
            count = n())

props_grp <- rbind(usa_grp, eu_grp, others_grp)

props_grp %>% 
  ggplot(aes(x = region, y = prop, fill = genre)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Proportion of Movie Genres by Region", 
       x = "Region", 
       y = "Proportion") +
  scale_fill_brewer(palette = "Set1") +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  )

genre_region_props

# Conduct a chisquare test for this contingency table
# Take the first genre
# kg <- kg %>% 
#   mutate(main_genre = strsplit(genres, "\\|"))
# unique(kg$genres)

# 2- Genre profit over years KG
summary(kg[, c("budget", "gross")])
nrow(kg[kg$budget==0, ])
nrow(kg[kg$gross==0, ])
# As movies can't be produced for free, remove all observations with budget=0.
# Additionally, some budget entries are in millions. Take budget greater than 10000.
kg %<>% 
  filter(budget > 10000)

# There are some flops and wrong values for revenues. Get rid of them, too.
kg %<>% 
  filter(gross > 10000)

kg %<>%
  mutate(profit = (gross - budget) / budget * 100)
# There are some outliers. We decided to increase outlier tolerance as they are true
# but extreme values. Remove the 3 highest profits.
summary(kg$profit)

kg %<>%
  filter(profit < sort(kg$profit, decreasing = T)[3])

genre_profits <- kg %>% 
  group_by(genre) %>% 
  summarize(avg_profit = mean(profit, na.rm =T)) %>% 
  arrange(desc(avg_profit)) # Take top four and plot on a time series

genre_profits

# Family seems unusually high
kg %>% 
  filter(genre=="Family") %>% 
  arrange(profit)

# Our sample size is extremely small with an extreme observation
# Also, we did not consider thriller because of its small sample size.

# These are the highest viable profiting genres on average
top_genre_list <- c("Horror", "Drama", "Comedy", "Animation")

# Construct a time-series plot
profit_df <- kg %>% 
  filter(genre %in% top_genre_list) %>% 
  group_by(year, genre) %>% 
  summarize(avg_profit_perc = mean(profit, na.rm = T))

profit_time_series <- ggplot(profit_df, aes(x=year, y=avg_profit_perc, color=genre)) +
  geom_line() +
  geom_point()

profit_time_series # Comment on our findings

# The horror genre seems extremely profitable
# To observe the relationship among the others better, plot without horror

profit_time_series_no_horror <- profit_df %>% 
  filter(genre != "Horror") %>% 
  ggplot(aes(x = year, y = avg_profit_perc, color = genre)) +
  geom_line() +
  geom_point() +
  labs(title = "Average Profit Percentage Over Time by Genre (Excluding Horror)", 
       x = "Year", 
       y = "Average Profit Percentage") +
  scale_color_brewer(palette = "Set1") +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold")
  )

profit_time_series_no_horror # Comment on our findings


#####################################################################
# 3- Compare most successful directors

sum(is.na(kg))
## colnames(cinema)
kg %>% 
  filter(genre == "Drama") %>% 
  nrow()
## Extract most profitable 15 directors for action genre.
action_directors <- kg %>% 
  filter(genre=="Action") %>% 
  group_by(director) %>% 
  summarise(total_profit =sum(profit,na.rm = TRUE)) %>% 
  arrange(desc(total_profit)) %>% 
  slice_head(n=15)

## Extract most profitable 15 directors for drama genre.

drama_directors <- kg %>%
  filter(genre == "Drama") %>%
  group_by(director) %>%
  summarise(total_profit = sum(profit, na.rm = TRUE)) %>%
  arrange(desc(total_profit)) %>%
  slice_head(n = 15)

## Combine most profitable directors and their profits in drama genre.
## There are giants like Clint Eastwood, Steven Spielberg, James Cameron.
top_drama_directors <- drama_directors$director
drama_profits <- kg %>%
  filter(director %in% top_drama_directors & genre == "Drama") %>%
  arrange(desc(profit)) %>% 
  select(director, profit)
drama_profits

## Combine most profitable directors and their profits in action genre.
## There are giants like J.J Abrams, Michael Bay and James Cameron.
top_action_directors <- action_directors$director
action_profits <- kg %>%
  filter(director %in% top_action_directors & genre == "Action") %>%
  arrange(desc(profit)) %>% 
  select(director, profit)
action_profits
# Combine the profits data for the t-test
combined_profits <- rbind(
  data.frame(director = drama_profits$director, profit = drama_profits$profit, genre = "Drama"),
  data.frame(director = action_profits$director, profit = action_profits$profit, genre = "Action")
)

# Print combined profits data for verification
print(combined_profits)

# Separate the profits by genre
drama_profit_values <- combined_profits %>%
  filter(genre == "Drama") %>%
  pull(profit)
action_profit_values <- combined_profits %>%
  filter(genre == "Action") %>%
  pull(profit)
drama_profit_values
action_profit_values



t_test_result <- t.test(drama_profit_values, action_profit_values)
t_test_result



## p - value is 0.004181
## based on a 95% confidence interval, since p-value < 0.05, there is a significant difference between 
## the mean profits of the most successful 15 directors in the Action and Drama genres.


########################################################################
# Let's analyze the top 10 most successful movies for the past 40 years

top10blockbusters <- read.csv("blockbuster-top_ten_movies_per_year_DFE.csv")

head(top10blockbusters)
str(top10blockbusters)

# alter worldwide_gross to numeric
top10blockbusters$worldwide_gross <- as.numeric(gsub("[\\$,]", "", top10blockbusters$worldwide_gross))

# group year and get the top 10 movies by worldwide gross for each year
top10blockbusters <- top10blockbusters %>%
  group_by(year) %>%
  top_n(10, worldwide_gross)


# the average worldwide gross
average_gross_per_year <- top10blockbusters %>%
  group_by(year) %>%
  summarise(average_gross = mean(worldwide_gross))


# plotting gross(profit!) of top 10 films for every year 

ggplot(average_gross_per_year, aes(x = year, y = average_gross / 1e6)) +
  geom_line(color = "blue", size = 1) +
  geom_point(color = "red", size = 2) +
  labs(title = "Average Gross of Top 10 Movies Worldwide by Year",
       subtitle = "Data represents the average gross of the top 10 highest-grossing movies each year",
       x = "Year",
       y = "Average Gross (in million $)") +
  theme_minimal()



#Is there a significant trend in the average gross of the top 10 movies worldwide over the years?


# linear regression model
linear_model <- lm(average_gross ~ year, data = average_gross_per_year)
summary(linear_model)

#intercept: -4.456e+10
#Both coefficients have p-values < 2e-16, which are highly significant, indicating strong evidence against the null hypothesis.
#p-value: < 2.2e-16
#The p-value associated with the F-statistic is extremely low, indicating that the model is highly significant.
#The model is statistically significant, indicating a strong relationship between the year and the average gross of the top 10 movies.
#The high R-squared value indicates that the model explains a large proportion of the variance in the average gross, suggesting a strong fit.

#normally distrubuted

par(mfrow = c(2, 2))
plot(linear_model)


##Non-Linearity: The slight curve in the Residuals vs Fitted plot suggests that a simple linear model might not be the best fit. 
##A polynomial regression or another non-linear model might capture the relationship better.
#Normality of Residuals: The normality assumption is reasonably satisfied, though there are some deviations at the extremes.
#Homoscedasticity: There is a slight indication of heteroscedasticity, but it is not severe.
#Influential Points: Points 35 and 38 could be influential and should be examined further.



# normality of residuals
shapiro.test(linear_model$residuals)



# Plot the polynomial regression
ggplot(average_gross_per_year, aes(x = year, y = average_gross / 1e6)) +
  geom_point(color = "red", size = 2) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, color = "blue", size = 1) +
  labs(title = "Polynomial Regression: Average Gross of Top 10 Movies Worldwide by Year",
       subtitle = "Data represents the average gross of the top 10 highest-grossing movies each year",
       x = "Year",
       y = "Average Gross (in million $)") +
  theme_minimal()


# launch ANOVA test to compare the models

######################################################

# 4- Production company analysis

dist <- read.csv("Movie_Distributors_1995-2019.csv")
head(dist)
sum(is.na(dist))


ggplot(dist, aes(x = Year, y = Gross.Revenue, color = X.Distributor)) +
  geom_line(aes(group = X.Distributor)) +
  geom_point() +
  labs(title = "Total Gross Revenue Over the Years by Distributor", 
       x = "Year", 
       y = "Total Gross Revenue") +
  theme_minimal()

# Plot number of movies over the years
ggplot(dist, aes(x = Year, y = Films.Distributed, color = Distributor)) +
  geom_line(aes(group = X.Distributor)) +
  geom_point() +
  labs(title = "Number of Movies Released Over the Years by Distributor", 
       x = "Year", 
       y = "Number of Movies") +
  theme_minimal()

# Plot average gross revenue per film over the years
ggplot(dist, aes(x = Year, y = Revenue.per.Film, color = X.Distributor)) +
  geom_line(aes(group = X.Distributor)) +
  geom_point() +
  labs(title = "Average Gross Revenue Per Film Over the Years by Distributor", 
       x = "Year", 
       y = "Average Gross Revenue Per Film") +
  theme_minimal()

ggplot(dist, aes(x = Year, y = Gross.Revenue, color = X.Distributor)) +
  geom_line(aes(group = X.Distributor)) +
  geom_point() +
  labs(title = "Total Gross Revenue Over the Years by Distributor", 
       x = "Year", 
       y = "Total Gross Revenue") +
  theme_minimal()







