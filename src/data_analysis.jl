using GLM, DataFrames, Statistics, Random

"""
    split_dataset(df, test_size; random_selection = true, seed = nothing) -> (df_training, df_test)

Split `df` into a training and a test set. `df` itself is not changed and both sets keep the original order of the rows.

- `test_size`:          share of the rows in the test set, as decimal (`0.2`) or in percent (`20`); values above 1 are percent.
- `random_selection`:   `true` draws the test rows at random (`seed` makes the draw reproducible), `false` uses the last rows.

Returns a DataFrame `df_training` containing the training data and DataFrame `df_test` containing the testing data.

```jldoctest

```
"""
function split_dataset(df::DataFrame, test_size::Real; random_selection::Bool = true, seed::Union{Int,Nothing} = nothing)
    
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
