"""
    run_training_pipeline(filepath = CONFIG.filepath) -> NamedTuple

Run data pre-processing pipeline for the training data used in the regression model. Import the listings.csv 
file into a DataFrame and run all pre-processing steps in the order of the design: select columns, rename, 
set types, remove duplicates and listings without bookings, handle missing values, remove zero denominators 
and outliers,  create dummies, ratios and the distance to the city center. Every step is controlled by `CONFIG`.

Returns a named tuple `(df, fitted)`:
- `df`: the processed listings as DataFrame.
- `fitted`: the values learned from the training data, which the inference pipeline has to reuse on a single
  apartment: `caps` (upper limits per room type), `kept_districts` (districts that are not grouped as rare)
  and `square_centers` (the centres of the squared columns).

<!-- TODO: add an `# Examples` section with a jldoctest once this function is implemented. -->
"""
function run_training_pipeline(filepath::String = CONFIG.filepath)
    df = import_csv(filepath)
    df = filter_columns(df, CONFIG.relevant_columns)
    format_labels!(df, CONFIG.label_mapping)
    set_types!(df, CONFIG.column_types)
    convert_currency!(df, CONFIG.currency_rules, CONFIG.cities[CONFIG.city].currency)
    remove_duplicates!(df, CONFIG.deduplicate_columns)
    remove_if_zero!(df, CONFIG.no_booking_columns)
    process_missing!(df, CONFIG.missing_rules)
    # a ratio is undefined for a denominator of 0: the denominator columns are taken from the ratio rules,
    # this has to happen after process_missing!() which fills their missing values
    denominators = unique(Symbol[rule.denominator for rule in CONFIG.ratio_rules if rule.denominator isa Symbol])
    remove_if_zero!(df, denominators)
    process_outliers!(df, CONFIG.outlier_rules)
    remove_implausible!(df, CONFIG.plausibility_rules)
    caps = compute_caps(df, CONFIG.cap_rules)
    cap_values!(df, caps, CONFIG.cap_rules)
    for rule in CONFIG.dummy_rules
        format_dummies!(df, rule)
    end
    for rule in CONFIG.ratio_rules
        calculate_ratio!(df, rule)
    end
    calculate_distance!(df, CONFIG.distance_rule, CONFIG.cities[CONFIG.city].center)
    kept = kept_categories(df, CONFIG.category_rule)
    group_rare_categories!(df, CONFIG.category_rule, kept)
    centers = Dict{Symbol,Float64}()
    for rule in CONFIG.square_rules
        centers[rule.source] = square_center(df, rule)
        calculate_square!(df, rule, centers[rule.source])
    end
    return (df = df, fitted = (caps = caps, kept_districts = kept, square_centers = centers))
end

"""
    run_prediction_pipeline(analysis, df, group)

Collect every number of the result screen for one prepared apartment: its price range, booked nights,
revenue, for a listed apartment the assessment of its current price, and the tips to raise the price.

# Arguments
- `analysis::NamedTuple`: The result of `run_analysis_pipeline` with the fitted models and the training data.
- `df::DataFrame`:        One prepared apartment (one row) with every predictor of the price model.
- `group::Symbol`:        `:listed` for an apartment that is already rented out, `:new` for one that is not.

Returns the bundle for `visualize_results`: `group`, `level`, `price` (`median`, `mean`, `lower`, `upper`),
`nights`, `revenue` (`estimate`, `lower`, `upper`), `current_price`, `assessment` (`status`, `difference`),
`district`, `room_type`, `tips` and `rating_tips`. Throws an `ArgumentError` for any other group.
"""
function run_prediction_pipeline(analysis::NamedTuple, df::DataFrame, group::Symbol)
    # 1. only the two groups of the menu are allowed
    group in (:listed, :new) || throw(ArgumentError("group must be :listed or :new, got :$group"))

    # 2. the price range from the price model, the first element of each vector is our one apartment
    fit = get_fit(analysis.fits, :price)
    r = predict_price_range(fit, df; level = CONFIG.interval_level)
    price = (median = r.median[1], mean = r.mean[1], lower = r.lower[1], upper = r.upper[1])

    # 3. the typical occupancy of comparable listings (same district and room type)
    district = String(df.district[1])
    room_type = String(df.room_type[1])
    reference = occupancy_reference(analysis.df_training, district, room_type, CONFIG.occupancy_rule)
    # String() turns the compact text type from CSV into plain text, occupancy_reference compares with it

    # 4. booked nights per year: a listed apartment has its own, a new one gets the typical occupancy
    nights = group == :listed ? Float64(df.estimated_occupancy_l365d[1]) : reference * 365

    # 5. revenue: the mean price times the nights; only a listed apartment gets a range
    estimate = price.mean * nights
    if group == :listed
        revenue = (estimate = estimate, lower = price.lower * nights, upper = price.upper * nights)
    else
        revenue = (estimate = estimate, lower = nothing, upper = nothing)
    end
    # the mean is used because revenue is an expected total, the recommended price is the median

    # 6. listed apartments only: compare the current price with the range
    if group == :listed
        high = occupancy_reference(analysis.df_training, district, room_type, CONFIG.occupancy_rule;
                                   q = CONFIG.occupancy_rule.high_quantile)
        current_price = Float64(df.price[1])
        assessment = assess_listing(current_price, price.lower, price.upper, nights / 365, high)
    else
        current_price = nothing
        assessment = nothing
    end
    # high is the occupancy that counts as "well booked" for comparable listings

    # 7. tips: empty tables in the final shape until amenity_effects and rating_effects are merged
    # TODO (#186): replace with amenity_effects and rating_effects
    tips = DataFrame(amenity = Symbol[], change = Float64[], change_pct = Float64[])
    rating_tips = DataFrame(score = Symbol[], pct_per_step = Float64[])

    # 8. one bundle with every number of the screen
    return (group = group, level = CONFIG.interval_level, price = price, nights = nights, revenue = revenue,
            current_price = current_price, assessment = assessment, district = district,
            room_type = room_type, tips = tips, rating_tips = rating_tips)
end

"""
    run_analysis_pipeline(df)

Split the processed listings `df` (`result.df` of `run_training_pipeline`) into a training and a test set,
fit every model in `CONFIG.regression_models` on the training set, and score it on the test set.

# Arguments
- `df::DataFrame`: Processed listings table, the `df` part of the result of `run_training_pipeline()`.

Returns a named tuple containing the fitted models, their scores, the training set, and the test set.
The returned values are ordered the same way as `CONFIG.regression_models`, and the split is controlled by
`CONFIG.test_size` and `CONFIG.split_seed`.
"""
function run_analysis_pipeline(df::DataFrame)
    # 1. split the data into training and test set (same seed every time, so the split is reproducible)
    df_training, df_test = split_dataset(df, CONFIG.test_size; seed = CONFIG.split_seed)

    # 2. fit every model of CONFIG.regression_models on the training set;
    # the base category of room type and district comes from CONFIG.reference_levels
    fits = [regression_city(df_training, spec; reference_levels = CONFIG.reference_levels) for spec in CONFIG.regression_models]

    # 3. score every fit on the test set
    scores = [evaluate_regression(fit, df_test) for fit in fits]

    return (fits = fits, scores = scores, df_training = df_training, df_test = df_test)
end


"""
    run_inference_pipeline() -> DataFrame

Run data pre-processing pipeline for the user input about a sigle apartment for the regression model to run a prediction.

Returns processed user input as DataFrame `df`.

<!-- TODO: add an `# Examples` section with a jldoctest once this function is implemented. -->
"""
function run_inference_pipeline()

end