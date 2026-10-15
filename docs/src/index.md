# HostWise.jl: Airbnb Price Estimator

## Description of Project
HostWise estimates a fair nightly price range and the expected yearly revenue of an apartment on Airbnb. The user chooses a city and answers a few questions about the apartment: room type, guests, bedrooms, beds, bathrooms, minimum nights, location, amenities and Superhost status. The program then shows the typical price of comparable listings, the range in which 80 % of them lie, the expected booked nights and revenue, tips to raise the price and the most similar listings nearby. For an apartment that is already listed, the user also enters the current price, rating and booked nights, and the program tells whether the price is below, within or above the range of comparable listings. A market findings screen shows the price level of the city, what drives the price and how well the models predict.

## Dataset
The data comes from Inside Airbnb (https://insideairbnb.com/get-the-data/), which publishes a detailed listings file for many cities as a CSV file. The program currently includes Athens (14 337 listings), Barcelona (15 293 listings) and Madrid (22 708 listings). Each file is one snapshot of all listings of the city with their price, size, amenities, location, reviews and Superhost status, and an estimate of the booked nights and the revenue of the last year. Listings with missing or implausible values are cleaned or removed before the analysis. More cities can be added without changing the code, see the README.

## Functions
The price is predicted with linear regression models (GLM.jl) on the logarithm of the price, fitted on 80 % of the listings and tested on the other 20 %. `predict()` from GLM gives an interval for the price of a single apartment, which is shown as the price range. The revenue is the predicted price times the booked nights: for a listed apartment its own booked nights, for a new apartment the typical occupancy of listings with the same district and room type. The significant coefficients of the models give the effect of an amenity, a better rating or the Superhost status in percent, which is used for the tips. The design of the program and its limits are described in [Project design](design.md), every function in the [Reference manual](manual.md).

## Ultimate Goal
The goal is to give hosts and future hosts an orientation for their price: what comparable listings ask, what they can expect to earn, and what would raise the price. The data is cross-sectional, so the program gives the overall price range of comparable listings, not a price for a specific date or season.

## How to use
Start the program from a terminal in the project folder with `julia src/main.jl`, choose a city and then an option of the main menu. The README describes the requirements, the menu and how to add a city.
