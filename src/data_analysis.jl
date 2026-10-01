using GLM, DataFrames, Statistics, Random

"""
    split_dataset(df, test_size; random_selection = true, seed = nothing) -> (df_training, df_test)

Split `df` into a training and a test set. `df` itself is not changed.

- `test_size`:          share of the rows in the test set, as decimal (`0.2`) or in percent (`20`); values above 1 are percent.
- `random_selection`:   `true` draws the test rows at random (`seed` makes the draw reproducible), `false` uses the last rows.

Returns a DataFrame `df_training` containing the training data and DataFrame `df_test` containing the testing data.

<!-- TODO: add an `# Examples` section with a jldoctest once this function is implemented. -->
"""
function split_dataset(df::DataFrame, test_size::Real; random_selection::Bool = true, seed::Union{Int,Nothing} = nothing)
    
    # convert test_size to decimal if it is given in percent (threshhold = 1)
    test_size > 1 && (test_size = test_size/100)

    # throw error if test_size is not between 0 and 1 (or in percent, e.g. 20)
    ((test_size >= 1 ? test_size/100 < 1 : test_size < 1) && test_size/100 > 0) || throw(ArgumentError("test_size has to be between 0 and 1 (or in percent, e.g. 20)"))
    # throw error if test_size would return empty DataFrame
    (round(test_size*nrow(df)) == 0 || round((1-test_size)*nrow(df)) == 0) && throw(ArgumentError("test_size too large, training_set is empty"))

    # set absolut test size value
    test_size_absolut = round(Int, test_size*nrow(df))
    
    # if random_selection is true, shuffle the rows of df
    if random_selection
        seed !== nothing && Random.seed!(seed)
        perm = randperm(round(Int, nrow(df)))
        df_perm = df[perm, : ]
        # take the last rows of df as test set
        df_training = first(df_perm, nrow(df) - test_size_absolut)
        df_testing = last(df_perm, test_size_absolut)
    else
        # take the last rows of df as test set
        df_training = first(df, nrow(df) - test_size_absolut)
        df_testing= last(df, test_size_absolut)
    end
    # return the training and testing DataFrames
    return df_training, df_testing
end


"""
    prepare_predictors(df, spec) -> DataFrame

Apply the predictor transformations specified in `spec.log1p_predictors` without changing `df` itself.
The selected columns are transformed using `log(1 + x)` before the model fit.

# Arguments
- `df::DataFrame`:      Input data frame.
- `spec::NamedTuple`:   Regression specification with the `log1p_predictors` field.

Returns a transformed DataFrame with the requested predictors adjusted for log-scaling.
"""
function prepare_predictors(df::DataFrame, spec::NamedTuple)
     # return DataFrame without transformations if log1p_predictors is empty
    isempty(spec.log1p_predictors) && return copy(df)
    # check for values <-1 and missing values and throw an error
    for check_col in spec.log1p_predictors
        any(ismissing, df[! , check_col]) && throw(ArgumentError("Missing value(s) in specified column!"))
        any(x -> x <= -1, df[! , check_col]) && throw(DomainError("Specified vector includes negative value(s) <-1!"))
    end

    # return transformed DataFrame
    return transform(df, spec.log1p_predictors .=> ByRow(log1p); renamecols = false)
end

"""
    regression_city(df_training, spec) -> (spec, model, smearing)

Fit one linear model. `spec` is one entry of `CONFIG.regression_models` with the fields `target`, `log_scale`,
`log1p_predictors` and `predictors`. Returns the spec, the fitted GLM model and the smearing factor that
[`predict_apartment_performance`](@ref) needs to turn predictions of a log model back into the units of the target.

Throws an error if a used column has missing values or, on the log scale, if the target has values of 0 or below.
"""
function regression_city(df_training::DataFrame, spec::NamedTuple)

end


"""
    predict_apartment_performance(fit, df_new) -> Vector

Predict the target of `fit` (the result of [`regression_city`](@ref)) in its own units, e.g. EUR, for the rows of `df_new`.
`df_new` has to be processed by the pre-processing steps and is not changed.
"""
function predict_apartment_performance(fit::NamedTuple, df_new::DataFrame)
   
end


"""
    evaluate_regression(fit, df_test) -> (n, r2_model_scale, r2, median_ae, mae)

Score a fitted model on data it was not fitted on, e.g. the test set of [`split_dataset`](@ref).
`r2_model_scale` is the R2 on the scale the model was fitted on (log scale for log models), `r2` the R2 in the units of the
target, `median_ae` and `mae` the typical and the mean absolute error in the units of the target.
"""
function evaluate_regression(fit::NamedTuple, df_test::DataFrame)
    
end
