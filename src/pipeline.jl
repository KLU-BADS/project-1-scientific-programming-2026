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
    run_inference_pipeline(df_input, fitted) -> DataFrame

Prepare the user's apartment for the price model: apply the same pre-processing steps as `run_training_pipeline`,
with the values learned on the training data, so the row looks exactly like a training row.

The steps, in the order of the training pipeline:
1. cap the sizes with the training caps of the room type (`cap_values!`);
2. calculate every ratio whose columns are in the input (`calculate_ratio!`); e.g. the occupancy rate only for listed apartments;
3. calculate the distance to the city center (`calculate_distance!`);
4. group a district that was rare in training as `"_other"` (`group_rare_categories!`);
5. calculate the centred squares with the training centres (`calculate_square!`);
6. check that every predictor of the `:price` model is there.

# Arguments
- `df_input::DataFrame`:    the user's answers as a one-row table, e.g. from `import_user_input`.
- `fitted::NamedTuple`:     the values learned on the training data, `fitted` of `run_training_pipeline`:
                            `caps`, `kept_districts` and `square_centers`.

# Throws
- `ArgumentError`   if a predictor of the `:price` model is missing after all steps; the message names it.
- `ArgumentError`   if there is no cap for the room type (a room type that was not in the training data).

Returns a new prepared table; `df_input` is not changed.
"""
function run_inference_pipeline(df_input::DataFrame, fitted::NamedTuple)
    df_inference = copy(df_input)
    cap_values!(df_inference, fitted.caps, CONFIG.cap_rules)
    for rule in CONFIG.ratio_rules
        if hasproperty(df_inference, rule.numerator) 
            if rule.denominator isa Real || hasproperty(df_inference, rule.denominator)
                calculate_ratio!(df_inference, rule)
            end
        end
    end
    calculate_distance!(df_inference, CONFIG.distance_rule, CONFIG.cities[CONFIG.city].center)
    group_rare_categories!(df_inference, CONFIG.category_rule, fitted.kept_districts)
    for rule in CONFIG.square_rules
        calculate_square!(df_inference, rule, fitted.square_centers[rule.source])
    end
    spec = only(filter(m -> m.name == :price, CONFIG.regression_models))
    missing_cols = setdiff(spec.predictors, propertynames(df_inference))
    isempty(missing_cols) || throw(ArgumentError("input is missing: $(join(missing_cols, ", "))"))
    return df_inference
end