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
<<<<<<< HEAD
    kept = kept_categories(df, CONFIG.category_rule)
    group_rare_categories!(df, CONFIG.category_rule, kept)
    centers = Dict{Symbol,Float64}()
    for rule in CONFIG.square_rules
        centers[rule.source] = square_center(df, rule)
        calculate_square!(df, rule, centers[rule.source])
    end
    return (df = df, fitted = (caps = caps, kept_districts = kept, square_centers = centers))
=======
    # 1. the values learned from the training data
    # the new steps (caps, rare districts, squares) will fill these; until they are implemented the values are empty placeholders
    # TODO: replace the placeholders with the results of compute_caps, kept_categories and square_center
    fitted = (
        caps = Dict{Tuple{String,Symbol},Float64}(),
        kept_districts = String[],
        square_centers = Dict{Symbol,Float64}(),
    )
    # 2. return the cleaned table together with the learned values
    # a named tuple lets the caller write result.df and result.fitted
    return (df = df, fitted = fitted)
>>>>>>> origin/main
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
    df_training, df_test = split_dataset(df, CONFIG.test_size; seed = CONFIG.split_seed)
    fits = [regression_city(df_training, spec) for spec in CONFIG.regression_models]
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