# This file contains the configuration for all the functions.
#
# All changes to input variables for any function in the project should be made here,
# including the selection of the variables relevant for the regression model, the
# corresponding label mapping, the definition of the column data types, the rules for
# all data pre-processing steps, and the regression model definition.

# The project root is found relative to this file, so paths work regardless of where Julia is started.
const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

# Configuration for data input, data pre-processing, and the regression model.
# Based on the variable proposal in the regression model overview.
#
# Naming: all rules below that are applied AFTER format_labels!() use the NEW column names
# (see label_mapping). Everything before format_labels!() (relevant_columns, label_mapping keys)
# uses the RAW names from listings.csv.
const CONFIG = (
    # Filepath for the import fuction for the listings.csv data file located in data/raw
    filepath = joinpath(PROJECT_ROOT, "data", "raw", lowercase(city) * "_listings.csv"),
    city = "Athens",                     # key into `cities`, selects the city center for calculate_distance!()

    # Configuration for filter_columns(): raw columns needed to build every variable of the regression model.
    relevant_columns = [
        :id,                                # only used to remove duplicates
        :room_type, :accommodates,          # basic facts
        :beds, :bedrooms, :bathrooms, :bathrooms_text,   # -> ratios (bathrooms_text fills missing bathrooms)
        :latitude, :longitude,              # -> proximity_city_center
        :amenities,                         # -> has_balcony, has_AC, allows_pets
        :estimated_occupancy_l365d, :availability_365,   # -> occupancy_rate, ratio_occupancy_availability
        :host_is_superhost,
        :review_scores_rating, :number_of_reviews, :reviews_per_month,
        :price, :estimated_revenue_l365d,   # dependent variables
    ],

    # Configuration for format_labels!(): raw name => name used everywhere after this step
    # (names from the model proposal).
    label_mapping = Dict{Symbol,Symbol}(
        :host_is_superhost            => :is_superhost,
        :number_of_reviews            => :number_ratings,
        :estimated_revenue_l365d      => :estimated_revenue,
    ),

    # Configuration for set_types!(): columns that need a type other than the one CSV.read infers.
    # Price is a String, e.g., "$409.00"; the rest are Float64 to avoid type errors.
    column_types = Dict{Symbol,DataType}(
        :price             => Float64,
        :estimated_revenue => Float64,
        :beds              => Float64,
        :bedrooms          => Float64,
        :bathrooms         => Float64,
    ),

    # Configuration for convert_currency!(): every amount is converted to base_currency
    currency_rules = (
        columns = [:price, :estimated_revenue],
        base_currency = "USD",
        exchange_rates = Dict(                    # value of 1 unit of the currency in EUR
            "USD" => 1.0,
        # add one line per new currency, e.g. "USD" => 0.92
        # rates as of <date>, source: <e.g. ECB reference rate>
        ),
    ),

    # Configuration for remove_duplicates!(): reference column for the removal of duplicates.
    duplicate_columns = [:id],

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
        :price                => :drop_row,
        :estimated_revenue    => :drop_row,
        :is_superhost         => :drop_row,
        :review_scores_rating => :drop_row,     # listings without any review cannot be rated
        :reviews_per_month    => :fill_zero,
        :bedrooms             => :impute_median_or_drop_entire_home,
        :beds                 => :impute_median_or_drop_entire_home,
        :bathrooms            => :fill_from_bathrooms_text,
    ],

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
        (target = :ratio_beds_bedrooms,             numerator = :beds,                      denominator = :bedrooms,          delete = false),
        (target = :ratio_accommodates_to_bathrooms, numerator = :accommodates,            denominator = :bathrooms,         delete = false),
        (target = :occupancy_rate,                  numerator = :estimated_occupancy_l365d, denominator = 365,                delete = false),
        (target = :ratio_occupancy_availability,    numerator = :estimated_occupancy_l365d, denominator = :availability_365,  delete = false),
    ],
    # Configuration for calculate_distance!(): distance of each listing to the city center of `city`.
    # Expansion to other distance calculations (e.g., major tourist attractions) is possible.
    #
    # rules:
    # target          distance of apartment to city center
    # source_column   reference to columns containing latitude and longitude of apartment
    # delete          optional flag to delete column after ratio calculation
    #
    # cities:
    # center          latitude and longitude of city center
    # currency        currency used in listings.csv city file
    distance_rule = (
        target = :proximity_city_center,
        source_columns = (latitude = :latitude, longitude = :longitude),
        delete = true,
    ),

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
    # log_scale = true: the model is fitted on log(target) and its predictions are transformed back
    # (price and revenue are strongly right-skewed; on the log scale the fit is better and the errors are proportional).
    # log1p_predictors: heavy-tailed predictors (e.g. up to 100 reviews per month) that enter the model as log(1 + x).
    # Revenue is calculated as price x estimated occupancy (100% of the rows), and the occupancy is itself an estimate based on
    # reviews. The revenue model therefore does not use the occupancy and review volume predictors, otherwise its R2 would
    # mostly reflect this calculation.
    regression_models = [
        (
            target = :price,
            log_scale = true,
            log1p_predictors = [:reviews_per_month, :number_ratings, :ratio_occupancy_availability],
            predictors = [
                :room_type, :accommodates,                                     # basic facts
                :ratio_beds_bedrooms, :ratio_accommodates_to_bathrooms,        # basic ratios
                :proximity_city_center,                  # location
                :has_balcony, :has_AC, :allows_pets,                           # amenities
                :has_kitchen, :has_pool, :has_tv, :has_kettle, :has_washer,
                :has_dishwasher, :has_elevator, :has_self_checkin,
                :occupancy_rate, :ratio_occupancy_availability,                # occupancy
                :is_superhost,                                                 # host
                :review_scores_rating, :number_ratings, :reviews_per_month,    # ratings
            ],
        ),
        (
            target = :estimated_revenue,
            log_scale = true,
            log1p_predictors = Symbol[],
            predictors = [
                :room_type, :accommodates,
                :ratio_beds_bedrooms, :ratio_accommodates_to_bathrooms,
                :proximity_city_center,
                :has_balcony, :has_AC, :allows_pets,
                :has_kitchen, :has_pool, :has_tv, :has_kettle, :has_washer,
                :has_dishwasher, :has_elevator, :has_self_checkin,
                :is_superhost,
                :review_scores_rating,
            ],
        ),
    ],

)
