# This file contains the configuration for all the functions.
#
# All changes to input variables for any function in the project should be made here,
# including the selection of the variables relevant for the regression model, the
# corresponding label mapping, the definition of the column data types, the rules for
# all data pre-processing steps, and the regression model definition.

# The project root is found relative to this file, so paths work regardless of where Julia is started.
const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

# The city the project runs on. It is a separate constant because a NamedTuple cannot
# refer to its own fields, so CONFIG.filepath cannot be built from CONFIG.city.
# Change it here to switch cities: it picks both the data file and the entry in `cities`.
const CITY = "Athens"

# Predictor groups of the regression models. They are separate constants for the same reason
# as CITY: a NamedTuple cannot refer to its own fields, so regression_models below cannot be
# built from other CONFIG fields.

# Amenity dummies created by format_dummies!()
const AMENITIES = [:has_balcony, :has_AC, :allows_pets, :has_kitchen,
    :has_pool, :has_tv, :has_kettle, :has_washer, :has_dishwasher,
    :has_elevator, :has_self_checkin]

# Sizes, location, minimum stay and host flag; used by all three models
const SIZE_LOCATION = [:room_type, :district, :accommodates, :accommodates_sq,
    :bedrooms, :beds, :bathrooms, :proximity_city_center,
    :minimum_nights, :is_superhost]

# The six rating sub-scores; used by the :price_explain model only
const SUBSCORES = [:review_scores_accuracy, :review_scores_cleanliness,
    :review_scores_checkin, :review_scores_communication,
    :review_scores_location, :review_scores_value]

# Configuration for data input, data pre-processing, and the regression model.
# Based on the variable proposal in the regression model overview.
#
# Naming: all rules below that are applied AFTER format_labels!() use the NEW column names
# (see label_mapping). Everything before format_labels!() (relevant_columns, label_mapping keys)
# uses the RAW names from listings.csv.
const CONFIG = (
    # Filepath for the import function: the <city>_listings.csv data file of CITY, located in data/raw
    filepath = joinpath(PROJECT_ROOT, "data", "raw", lowercase(CITY) * "_listings.csv"),
    city = CITY,                            # key into `cities`, selects the city center for calculate_distance!()

    # Configuration for filter_columns(): raw columns needed to build every variable of the regression model.
    relevant_columns = [
        :id,                                # only used to remove duplicates
        :room_type, :accommodates,          # basic facts
        :beds, :bedrooms, :bathrooms, :bathrooms_text,   # sizes (bathrooms_text fills missing bathrooms)
        :latitude, :longitude,              # -> proximity_city_center
        :neighbourhood_cleansed,            # -> district
        :amenities,                         # -> has_balcony, has_AC, allows_pets
        :minimum_nights,                    # -> log1p predictor of every model
        :estimated_occupancy_l365d, :availability_365,   # -> occupancy_rate, ratio_occupancy_availability
        :host_is_superhost,                 # -> is_superhost
        # review_scores_rating is a predictor; number_of_reviews and reviews_per_month are kept
        # for process_missing!() but no model uses them any more
        :review_scores_rating, :number_of_reviews, :reviews_per_month,
        :review_scores_accuracy, :review_scores_cleanliness,   # NEW
        :review_scores_checkin, :review_scores_communication,  # NEW
        :review_scores_location, :review_scores_value,         # NEW
        :price, :estimated_revenue_l365d,   # dependent variables
    ],

    # Configuration for format_labels!(): raw name => name used everywhere after this step
    # (names from the model proposal).
    label_mapping = Dict{Symbol,Symbol}(
        :host_is_superhost            => :is_superhost,
        :number_of_reviews            => :number_ratings,
        :estimated_revenue_l365d      => :estimated_revenue,
        :neighbourhood_cleansed       => :district,
    ),

    # Configuration for set_types!(): columns that need a type other than the one CSV.read infers.
    # Price is a String, e.g., "$409.00"; the rest are Float64 to avoid type errors.
    column_types = Dict{Symbol,DataType}(
        :price                          => Float64,
        :estimated_revenue              => Float64,
        :beds                           => Float64,
        :bedrooms                       => Float64,
        :bathrooms                      => Float64,
        :minimum_nights                 => Float64,
        :review_scores_accuracy         => Float64,
        :review_scores_cleanliness      => Float64,
        :review_scores_checkin          => Float64,
        :review_scores_communication    => Float64,
        :review_scores_location         => Float64,
        :review_scores_value            => Float64,
    ),

    # Configuration for convert_currency!(): every amount is converted to base_currency
    #
    # rules:
    # columns         columns holding the amounts that are converted
    # base_currency   currency every amount is converted to; only a label, the conversion
    #                 itself just multiplies by the rate of the city's currency
    # exchange_rates  rate per currency code; the key used is the currency of CITY (see `cities`)
    currency_rules = (
        columns = [:price, :estimated_revenue],
        base_currency = "EUR",
        exchange_rates = Dict("USD" => 0.89, "EUR" => 1.0),
        # value of 1 unit of the currency in EUR (1 USD = 0.89 EUR)
        # add one line per new currency
        # rates as of 2 Oct 2026, source: Morningstar
    ),

    # Configuration for remove_duplicates!(): reference column for the removal of duplicates.
    deduplicate_columns = [:id],

    # Configuration for remove_if_zero!(): rows with a value of 0 (no bookings in the last 365 days) are removed.
    # The denominators of ratio_rules are checked for 0 in the same way; they are taken from ratio_rules and not listed here.
    no_booking_columns = [:estimated_revenue],

    # room_type value of entire homes (used by :impute_median_or_drop_entire_home)
    entire_home_label = "Entire home/apt",

    # Configuration for process_missing!():
    # Pair: column => rule, applied in this order (a column can appear more than once).
    #
    # rules:
    # :drop_row                            remove the row
    # :fill_zero                           replace with 0
    # :impute_median_by_room_type          median of the same room_type
    # :impute_median_or_drop_entire_home   as above, but entire homes are dropped: their bedrooms/beds vary too much to guess
    #                                     (most missing bedrooms/beds are private rooms, 96% of them have 1 bedroom)
    # :fill_from_bathrooms_text            parse the number from bathrooms_text, e.g. "1.5 shared baths" -> 1.5, "Half-bath" -> 0.5
    missing_rules = Pair{Symbol,Symbol}[
        :price                          => :drop_row,
        :estimated_revenue              => :drop_row,
        :is_superhost                   => :drop_row,
        :review_scores_rating           => :drop_row,     # listings without any review cannot be rated
        :reviews_per_month              => :fill_zero,
        :bedrooms                       => :impute_median_or_drop_entire_home,
        :beds                           => :impute_median_or_drop_entire_home,
        :bathrooms                      => :fill_from_bathrooms_text,
        :minimum_nights                 => :drop_row,
        :review_scores_accuracy         => :drop_row,
        :review_scores_cleanliness      => :drop_row,
        :review_scores_checkin          => :drop_row,
        :review_scores_communication    => :drop_row,
        :review_scores_location         => :drop_row,
        :review_scores_value            => :drop_row,
    ],

    # Configuration for remove_implausible!()
    # rows breaking a rule are removed in training; the input uses the same limits
    #
    # rule: column <= factor * max_of + offset
    plausibility_rules = [
        (column = :bedrooms,  max_of = :accommodates, factor = 1.0, offset = 0.0),
        (column = :bathrooms, max_of = :bedrooms,     factor = 1.0, offset = 2.0),
        (column = :beds,      max_of = :accommodates, factor = 2.0, offset = 0.0),
    ],

    # Configuration for compute_caps() and cap_values!()
    # sizes above the 99.5th percentile of their room type are capped
    cap_rules = (columns = [:accommodates, :bedrooms, :beds, :bathrooms],
                 group_by = :room_type, quantile = 0.995),

    # Configuration for process_outliers!():
    # Function uses the IQR (interquartile range) method to identify outliers.
    # Rows outside [Q1 - m*IQR, Q3 + m*IQR] in one of the columns are removed.
    #
    # rules:
    # columns         names of columns that are checked for outliers
    # method          describes the method used to process outliers (initial function only implements IQR)
    # iqr_multiplier  IQR multiplier
    # scale = :log    checks log(value) instead of the value: price and revenue are strongly right-skewed
    # action          rule for handling outliers
    outlier_rules = (
        columns = [:price, :estimated_revenue],
        method = :iqr,
        iqr_multiplier = 1.5,
        scale = :log,           # :log or :raw
        action = :drop_row,
    ),

    # Configuration for format_dummies!(): a dummy is 1 if the source text contains one of the keywords.
    #
    # rules:
    # source          reference to source column containing unformatted dummy variable
    # target          dummy variable name
    # keywords        set of keywords used in the listings.csv file
    # delete          optional flag to delete column after dummy conversion
    dummy_rules = [
        (source = :amenities,     target = :has_balcony,  keywords = ["balcony"],                     delete = false),
        (source = :amenities,     target = :has_AC,       keywords = ["air conditioning", "ac -"],    delete = false),
        (source = :amenities,     target = :allows_pets,  keywords = ["pets allowed"],                delete = false),
        # every item of the amenities text is in double quotes, a leading " restricts a keyword to the start of an item:
        # "\"washer" finds "Washer" and "Washer - In unit" but not "Dishwasher", "\"pool\"" does not find "Pool table"
        (source = :amenities,     target = :has_kitchen,  keywords = ["\"kitchen\"", "kitchenette"],  delete = false),
        (source = :amenities,     target = :has_pool,     keywords = ["\"pool\"", "\"pool -", "shared pool", "private pool", "outdoor pool", "indoor pool"], delete = false),
        (source = :amenities,     target = :has_tv,       keywords = ["tv"],                          delete = false),
        (source = :amenities,     target = :has_kettle,   keywords = ["hot water kettle"],            delete = false),
        (source = :amenities,     target = :has_washer,   keywords = ["\"washer", "free washer", "paid washer"], delete = false),
        (source = :amenities,     target = :has_dishwasher, keywords = ["\"dishwasher\""],            delete = false),
        (source = :amenities,     target = :has_elevator, keywords = ["\"elevator\""],                delete = false),
        (source = :amenities,     target = :has_self_checkin, keywords = ["self check-in"],           delete = false),
        # source and target are the same column: the "t"/"f" flag is replaced by 1/0 in place
        (source = :is_superhost,  target = :is_superhost, keywords = ["t"],                           delete = false),
    ],

    # Configuration for calculate_ratio!(): value in target = numerator / denominator
    # (denominator is a column or a constant). A ratio is undefined for 0, so rows with 0 in a denominator
    # column are removed by remove_if_zero!().
    #
    # rules:
    # target          ratio value
    # numerator       ratio numerator
    # denominator     ratio denominator
    # delete          optional flag to delete column after ratio calculation
    ratio_rules = [
        (target = :occupancy_rate,                  numerator = :estimated_occupancy_l365d, denominator = 365,                delete = false),
        (target = :ratio_occupancy_availability,    numerator = :estimated_occupancy_l365d, denominator = :availability_365,  delete = false),
    ],

    # Configuration for calculate_distance!(): distance of each listing to the city center of `city`.
    # Expansion to other distance calculations (e.g., major tourist attractions) is possible.
    #
    # rules:
    # target          distance of apartment to city center
    # source_columns  references to the columns holding latitude and longitude of the apartment
    # delete          optional flag to delete the latitude and longitude columns after the calculation
    #                 (false here: the coordinates are still needed to derive a user's district)
    distance_rule = (
        target = :proximity_city_center,
        source_columns = (latitude = :latitude, longitude = :longitude),
        delete = false,
    ),

    # Configuration for kept_categories() and group_rare_categories!()
    # districts with fewer than 20 listings are merged
    category_rule = (column = :district, min_count = 20, other_label = "_other"),

    # Configuration for square_center() and calculate_square!()
    # centred squares
    square_rules = [
        (source = :accommodates,         target = :accommodates_sq, center = true),
        (source = :review_scores_rating, target = :rating_sq,       center = true),
    ],

    # Known cities, keyed by the value of CITY:
    # center          latitude and longitude of the city center, used by calculate_distance!()
    # currency        currency of that city's listings file, selects the rate in currency_rules
    cities = Dict(
        "Athens"    => (center = (latitude = 37.9838, longitude = 23.7275), currency = "USD"),
        "Barcelona" => (center = (latitude = 41.3851, longitude = 2.1734), currency = "USD"),
        "Madrid"    => (center = (latitude = 40.4168, longitude = -3.7038), currency = "USD"),
    ),

    # Configuration for split_dataset!(): share of the listings kept back to test the models
    # (0.2 = 20%); the seed makes the split reproducible.
    test_size = 0.2,
    split_seed = 42,

    # Configuration for regression_city(): one linear model per entry.
    #
    # rules:
    # name              identifies the model; code looks a fit up by name, not by position
    # target            dependent variable of the model
    # log_scale         fit on log(target) and transform the predictions back
    # log1p_predictors  predictors that enter the model as log(1 + x)
    # predictors        independent variables of the model
    #
    # log_scale = true: the model is fitted on log(target) and its predictions are transformed back
    # (price and revenue are strongly right-skewed; on the log scale the fit is better and the errors are proportional).
    # log1p_predictors: heavy-tailed predictors, here the minimum nights per stay, that enter as log(1 + x).
    #
    # the three models:
    # :price             the only model used for a prediction shown to a user
    # :price_explain     the six rating sub-scores instead of the overall rating and its square;
    #                    for the findings and the rating tips only, never for a user's price
    # :revenue_baseline  for the report only. Revenue itself is calculated as predicted price x booked
    #                    nights, because estimated_revenue is price x estimated occupancy in the raw data.
    regression_models = [
        (name = :price, target = :price, log_scale = true,
        log1p_predictors = [:minimum_nights],
        predictors = vcat(SIZE_LOCATION, [:review_scores_rating, :rating_sq], AMENITIES)),

        (name = :price_explain, target = :price, log_scale = true,
        log1p_predictors = [:minimum_nights],
        predictors = vcat(SIZE_LOCATION, SUBSCORES, AMENITIES)),

        (name = :revenue_baseline, target = :estimated_revenue, log_scale = true,
        log1p_predictors = [:minimum_nights],
        predictors = vcat(SIZE_LOCATION, [:review_scores_rating, :rating_sq], AMENITIES)),
    ],

    # reference category per text predictor (:most_common = most listings)
    reference_levels = Dict(:room_type => :most_common, :district => :most_common),

    interval_level      = 0.8,   # share of comparable apartments in the price range
    significance_level  = 0.05,  # p-value limit for tips and findings
    min_effect_pct      = 1.0,   # smallest amenity effect worth a tip, in %
    min_room_type_count = 30,    # rarer room types are not offered or plotted

    # occupancy of comparable listings: revenue of new apartments, "high occupancy"
    occupancy_rule = (group_by = [:district, :room_type], min_count = 20,
                    fallback = :room_type, high_quantile = 0.5),

    # amenities a host can add; :has_kitchen is still for the team to decide
    actionable_amenities = [:has_AC, :has_tv, :has_kettle, :has_washer,
                            :has_dishwasher, :has_self_checkin, :allows_pets],

    # rating tips from :price_explain, effect per 0.1 point
    rating_tips = (columns = [:review_scores_cleanliness, :review_scores_accuracy],
                step = 0.1),

    # groups for the importance chart in the findings
    importance_groups = [
        "Size"           => [:accommodates, :accommodates_sq, :bedrooms, :beds, :bathrooms],
        "Location"       => [:district, :proximity_city_center],
        "Minimum nights" => [:minimum_nights],
        "Room type"      => [:room_type],
        "Amenities"      => AMENITIES,
        "Rating"         => [:review_scores_rating, :rating_sq],
        "Superhost"      => [:is_superhost],
    ],

    # menu text for every amenity
    amenity_labels = Dict(
        :has_balcony => "Balcony", :has_AC => "Air conditioning",
        :allows_pets => "Pets allowed", :has_kitchen => "Kitchen or kitchenette",
        :has_pool => "Pool", :has_tv => "TV", :has_kettle => "Kettle",
        :has_washer => "Washing machine", :has_dishwasher => "Dishwasher",
        :has_elevator => "Elevator", :has_self_checkin => "Self check-in",
    ),

    # readable names of coefficients (names as coeftable writes them)
    term_labels = Dict(
        "accommodates" => "each extra guest",
        "proximity_city_center" => "each km from the centre",
        "minimum_nights" => "longer minimum stay (log)",
        "room_type: Private room" => "private room instead of entire home",
        "is_superhost" => "Superhost",
        "review_scores_cleanliness" => "cleanliness rating",
        "review_scores_accuracy" => "accuracy rating",
    ),

    # Configuration for enter_apartment_data(): the numeric questions, in the order they are asked.
    #
    # rules:
    # column          column the answer is stored in
    # value_type      type the answer is parsed into
    # min, max        fixed limits; nothing = take the limit from the training data of the room type
    # prompt          question shown to the user
    # groups          :new (not listed yet), :listed, or both
    input_rules = [
        (column = :accommodates, value_type = Int, min = 1, max = nothing,
         prompt = "Maximum number of guests: ", groups = [:new, :listed]),
        (column = :bedrooms, value_type = Int, min = nothing, max = nothing,
         prompt = "Number of bedrooms: ", groups = [:new, :listed]),
        (column = :beds, value_type = Int, min = 1, max = nothing,
         prompt = "Number of beds: ", groups = [:new, :listed]),
        (column = :bathrooms, value_type = Float64, min = 0.5, max = nothing,
         prompt = "Number of bathrooms (half bath = 0.5): ", groups = [:new, :listed]),
        (column = :minimum_nights, value_type = Int, min = 1, max = nothing,
         prompt = "Minimum nights per stay: ", groups = [:new, :listed]),
        (column = :price, value_type = Float64, min = nothing, max = nothing,
         prompt = "Your current price per night (EUR): ", groups = [:listed]),
        (column = :review_scores_rating, value_type = Float64, min = 1.0, max = 5.0,
         prompt = "Your average rating (1 to 5): ", groups = [:listed]),
        (column = :estimated_occupancy_l365d, value_type = Int, min = 1, max = 255,
         prompt = "Nights booked in the last 12 months: ", groups = [:listed]),
    ],

    # Configuration for ask_location(): latitude and longitude are limited to the extremes
    # of the training data, widened by margin (in degrees; 0.005 ≈ 500 m); the distance to the
    # city center must not exceed the training maximum.
        location_rule = (coordinate_margin_deg = 0.005, distance_margin_km = 0.5),

    # OPTIONAL, only if address lookup is implemented
    geocoding = (url = "https://nominatim.openstreetmap.org/search",
                user_agent = "KLU-Project1 student project (<team e-mail>)",
                country_code = "gr", timeout = 10),
)
