"""
    run_training_pipeline(filepath = CONFIG.filepath) -> DataFrame

Run data pre-processing pipeline for the training data used in the regression model. Import the listings.csv 
file into a DataFrame and run all pre-processing steps in the order of the design: select columns, rename, 
set types, remove duplicates and listings without bookings, handle missing values, remove zero denominators 
and outliers,  create dummies, ratios and the distance to the city center. Every step is controlled by `CONFIG`.

Returns processed listing as DataFrame `df`.

```jldoctest

```
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
    for rule in CONFIG.dummy_rules
        format_dummies!(df, rule)
    end
    for rule in CONFIG.ratio_rules
        calculate_ratio!(df, rule)
    end
    calculate_distance!(df, CONFIG.distance_rule, CONFIG.cities[CONFIG.city].center)
    return df
end

"""
    run_analysis_pipeline(df)

Split the processed listings `df` (the result of `run_training_pipeline`) into a training and a test set,
fit every model in `CONFIG.regression_models` on the training set, and score it on the test set.

# Arguments
- `df::DataFrame`: Processed listings data returned by `run_training_pipeline()`.

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

```jldoctest

```
"""
function run_inference_pipeline()

end