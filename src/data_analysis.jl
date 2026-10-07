using GLM, DataFrames, Statistics, Random

"""
    split_dataset(df, test_size; random_selection = true, seed = nothing) -> (df_training, df_test)

Split `df` into a training and a test set. `df` itself is not changed.

# Arguments
- `df::DataFrame`:           Input data frame.
- `test_size::Real`:         Share of the rows in the test set, as decimal (`0.2`) or in percent (`20`); values above 1 are percent.
- `random_selection::Bool`:  `true` draws the test rows at random (`seed` makes the draw reproducible), `false` uses the last rows.
- `seed`:                    Optional integer seed for a reproducible random split.

# Throws
- `ArgumentError` if test_size is not >0 and <1 (or <100 percent) or the training set or test set is empty.

Returns a DataFrame `df_training` containing the training data and DataFrame `df_test` containing the testing data.


# Examples

```jldoctest
julia> df = DataFrame(a = 1:10);

julia> df_training, df_test = split_dataset(df, 0.2; random_selection = false);

julia> nrow(df_training), nrow(df_test)
(8, 2)

julia> df_test.a == [9, 10]
true

julia> split_dataset(df, 20; seed = 42) == split_dataset(df, 0.2; seed = 42)
true
```
"""
function split_dataset(df::DataFrame, test_size::Real; random_selection::Bool = true, seed::Union{Int,Nothing} = nothing)
    # get number of rows
    n = nrow(df)
    # convert test_size to decimal if it is given in percent (threshhold = 1)
    test_fraction = test_size > 1 ? test_size / 100 : test_size
    # throw error if test_size is not between 0 and 1 (or in percent, e.g. 20)
    0 < test_fraction < 1 || throw(ArgumentError("test_size must be between 0 and 1 (or between 1 and 100 percent), got $(test_size)"))
    # throw error if test_size would return empty DataFrame
    n_test = round(Int, test_fraction * n)
    n_test == 0 && throw(ArgumentError("test_size $(test_size) gives an empty test set for $(n) rows"))
    n_test == n && throw(ArgumentError("test_size $(test_size) gives an empty training set for $(n) rows"))
    # if random_selection is true, shuffle the rows of df
    if random_selection
        seed !== nothing && Random.seed!(seed)
        perm = randperm(round(Int, n))
        df_perm = df[perm, : ]
        # take the last rows of df as test set
        df_training = first(df_perm, n - n_test)
        df_testing = last(df_perm, n_test)
    else
        # take the last rows of df as test set
        df_training = first(df, n - n_test)
        df_testing= last(df, n_test)
    end
    # return the training and testing DataFrames
    return df_training, df_testing
end


"""
    prepare_predictors(df, spec) -> DataFrame

Apply the predictor transformations specified in `spec.log1p_predictors` without changing `df` itself.
The selected columns are transformed using `log(1 + x)` before the model fit. Throw error if values are missing or <= -1 

# Arguments
- `df::DataFrame`:      Input data frame.
- `spec::NamedTuple`:   Regression specification with the `log1p_predictors` field.

# Throws
- `MissingException` if a vector contains missing values.
- `DomainError` if a vector contains a value <= -1.

Returns a transformed DataFrame with the requested predictors adjusted for log-scaling.


# Examples

 ```jldoctest
julia> df = DataFrame(reviews = [0.0, 1.0], rooms = [1, 2]);

julia> df_log = prepare_predictors(df, (log1p_predictors = [:reviews],));

julia> df_log.reviews ≈ [0.0, log(2)]
true

julia> df_log.rooms == [1, 2]
true

julia> df.reviews == [0.0, 1.0]
true
```
"""
function prepare_predictors(df::DataFrame, spec::NamedTuple)
     # return DataFrame without transformations if log1p_predictors is empty
    isempty(spec.log1p_predictors) && return copy(df)
    # check for column values <-1 and missing column values and throw an error
    for check_col in spec.log1p_predictors
        col = df[!, check_col]
        any(ismissing, col) && throw(MissingException("Missing value(s) in column $(check_col)"))
        any(x -> x <= -1, col) && throw(DomainError(minimum(col), "Value <=-1 in column $(check_col)"))
    end
    # return transformed DataFrame
    return transform(df, spec.log1p_predictors .=> ByRow(log1p); renamecols = false)
end

"""
    prepare_dependent(df, spec) -> (DataFrame, Symbol)

Apply the transformations for the dependent variable specified in `spec.log_scale` without changing `df` itself.
The column is transformed using `log()` before the model fit. Throw an error when values are missing or <=0. 

# Arguments
- `df::DataFrame`:      Input data frame.
- `spec::NamedTuple`:   Regression specification with the `log_scale` field.

# Throws
- `MissingException` if a vector contains missing values.
- `DomainError` if a vector contains a value <=0.

Returns a transformed DataFrame with the target column adjusted for log-scaling and the column reference.


# Examples

```jldoctest
julia> df = DataFrame(price = [100.0, 200.0]);

julia> data, dependent = Project1.prepare_dependent(df, (target = :price, log_scale = true));

julia> dependent
:log_price

julia> data.log_price ≈ log.([100.0, 200.0])
true

julia> Project1.prepare_dependent(df, (target = :price, log_scale = false))[2]
:price
```
"""
function prepare_dependent(df::DataFrame, spec::NamedTuple)
    # function call for non log_spec variables
    !spec.log_scale && return (copy(df), spec.target)
    # check for values <=0 and missing values and throw an error
    col = df[!, spec.target]
    any(ismissing, col) && throw(MissingException("target column $(spec.target) contains missing values"))
    any(x -> x <= 0, col) && throw(DomainError(minimum(col), "target column $(spec.target) contains values <= 0, log is undefined"))
    # rename column
    dependent = Symbol("log_", spec.target)
    # return transformed DataFrame
    return (transform(df, spec.target => ByRow(log) => dependent), dependent)
end

"""
    regression_city(df_training, spec; reference_levels = Dict{Symbol,Any}()) -> (spec, model, smearing)

Fit one linear model. `spec` is one entry of `CONFIG.regression_models` with the fields `target`, `log_scale`,
`log1p_predictors` and `predictors`.

# Arguments
- `df_training::DataFrame`:     Training data.
- `spec::NamedTuple`:           Regression specification
- `reference_levels`:           Optional Dict `column => reference category` (the base of a categorical predictor, without its own coefficient),
                                or `:most_common` for the category with the most rows. Columns that are not predictors of `spec` are ignored.
                                The default is an empty Dict: the first category is the base.

# Throws
- `MissingException` if the target or a predictor column contains missing values.
- `DomainError` if a log1p predictor contains a value <= -1, or, on the log scale, if the target contains a value <= 0.

Returns the spec, the fitted regression model and the smearing factor that [`predict_apartment_performance`](@ref)
needs to turn predictions of a log model back into the units of the target.


# Examples

```jldoctest
julia> df = DataFrame(x = [1.0, 2.0, 3.0, 4.0]);

julia> df.price = exp.(1 .+ 0.5 .* df.x);

julia> spec = (target = :price, log_scale = true, log1p_predictors = Symbol[], predictors = [:x]);

julia> fit = regression_city(df, spec);

julia> fit.spec.target
:price

julia> fit.smearing ≈ 1.0
true
```
"""
function regression_city(df_training::DataFrame, spec::NamedTuple; reference_levels = Dict{Symbol,Any}())
    # check target and predictor columns for missing values
    for check_col in vcat(spec.target, spec.predictors)
        any(ismissing, df_training[!, check_col]) && throw(MissingException("column $(check_col) contains missing values"))
    end
    # define input data
    data = prepare_predictors(df_training, spec)
    # add log target column with log values if log_scale is true
    if spec.log_scale 
        data, dependent = prepare_dependent(data, spec)
    else
        dependent = spec.target
    end
    # 1. the reference (base) category of each categorical predictor
    # the contrasts tell the model which category is the base, so it gets no coefficient of its own
    contrasts = Dict{Symbol,Any}()
    for (col, level) in reference_levels
        # 2. a column that is not a predictor of this model is ignored
        col in spec.predictors || continue
        # 3. :most_common means the category with the most rows, otherwise the given category is the base
        if level === :most_common
            counts = combine(groupby(df_training, col), nrow => :n)
            base = counts[argmax(counts.n), col]
        else
            base = level
        end
        # 4. DummyCoding with this base is passed to lm below
        contrasts[col] = DummyCoding(base = base)
    end
    # define model
    # with an empty contrasts Dict the fit is the same as before
    model = lm(Term(dependent) ~ sum(term.(spec.predictors)), data; contrasts = contrasts)
    # set Duan's smearing factor, responsible for getting the mean if dependent is log scale, as 1.0 for the return in case of no log-scale
    smearing = 1.0
    # exp(prediction) is the median of the dependent variable, not its mean; Duan's smearing factor corrects this (mean of exp(residuals))
    spec.log_scale && (smearing = mean(exp.(residuals(model))))
    #return tuple with fitted model
    return (spec = spec, model = model, smearing = smearing)
end


"""
    predict_apartment_performance(fit, df_new) -> Vector

Predict the target of `fit`, the result of `regression_city()`, in its own units, e.g. EUR, for the rows of `df_new`.
`df_new` has to be processed by the pre-processing steps and is not changed.

# Arguments
- `fit::NamedTuple`:       Fit of the regression model
- `df_new::DataFrame`:     Input data frame.

# Throws
- `MissingException` / `DomainError` from [`prepare_predictors`](@ref) if a log1p predictor is missing or <= -1.

Returns model prediction (corrected prediction in case of `log_scale` true)


# Examples

```jldoctest
julia> df = DataFrame(x = [1.0, 2.0, 3.0, 4.0]);

julia> df.price = exp.(1 .+ 0.5 .* df.x);

julia> spec = (target = :price, log_scale = true, log1p_predictors = Symbol[], predictors = [:x]);

julia> fit = regression_city(df, spec);

julia> predicted = predict_apartment_performance(fit, DataFrame(x = [5.0]));

julia> all(predicted .≈ [exp(3.5)])
true
```
"""
function predict_apartment_performance(fit::NamedTuple, df_new::DataFrame)
    # prediction on the scale the model was fitted on
    model_prediction = predict(fit.model, prepare_predictors(df_new, fit.spec))
    # if model does not use log-scale dependet variable return the predicted values
    !fit.spec.log_scale && return model_prediction
    # log models: exp gives the median, the smearing factor turns it into the mean
    median_prediction = exp.(model_prediction)
    mean_prediction = median_prediction .* fit.smearing
    return mean_prediction
end


"""
    evaluate_regression(fit, df_test) -> (n, r2_model_scale, r2, median_ae, mae)

Score a fitted model on a test data set it was not fitted on. 

# Arguments
- `fit::NamedTuple`:    Fit of the regression model
- `df_test::DataFrame`: Test data.

# Throws
- `DomainError`         if, on the log scale, the target contains a value <= 0.

Returns model evaluation containg the `n` (length), `r2_model_scale` is the R-squared on the scale the model 
was fitted on (log scale for log models), `r2` the R2 in the units of the target, `median_ae` and `mae` the 
typical and the mean absolute error in the units of the target.


# Examples

```jldoctest
julia> df = DataFrame(x = [1.0, 2.0, 3.0, 4.0]);

julia> df.price = exp.(1 .+ 0.5 .* df.x);

julia> spec = (target = :price, log_scale = true, log1p_predictors = Symbol[], predictors = [:x]);

julia> fit = regression_city(df, spec);

julia> df_test = DataFrame(x = [5.0, 6.0], price = exp.(1 .+ 0.5 .* [5.0, 6.0]));

julia> result = evaluate_regression(fit, df_test);

julia> result.n
2

julia> result.r2 ≈ 1.0 && result.r2_model_scale ≈ 1.0
true

julia> isapprox(result.mae, 0.0; atol = 1e-8)
true
```
"""
function evaluate_regression(fit::NamedTuple, df_test::DataFrame)
    # get vector of dependent variable from test set
    actual = df_test[!, fit.spec.target]
    # check for values <0 in case of log scale
    fit.spec.log_scale && any(x -> x <= 0, actual) && throw(DomainError(minimum(actual), "Value <=0 in target column $(fit.spec.target)"))
    # predict test set
    predicted = predict_apartment_performance(fit, df_test)
    # get R-squared to measure how well the predictions are in Euro
    r2 = get_r2(actual, predicted)
    if fit.spec.log_scale
        log_predicted = predict(fit.model, prepare_predictors(df_test, fit.spec))
        r2_model_scale = get_r2(log.(actual), log_predicted)
    else
        r2_model_scale = r2
    end
    # calculate the errors
    errors = abs.(predicted .- actual)
    # return evaluation results
    return (n = length(actual), r2_model_scale = r2_model_scale, r2 = r2, median_ae = median(errors), mae = mean(errors))
end


"""
    get_r2(y, y_hat) -> r2

Helper function to calculate the R^2 values for a regression.

# Arguments
- `y::AbstractVector`:         Actual values.
- `y_hat::AbstractVector`:     Predicted values.

# Throws
- `DimensionMismatch`       if `y` and `y_hat` have different lengths.
- `ArgumentError`           if the vectors are empty or `y` is constant (R² undefined)
- `MissingException`        if a vector contains missing values.

Returns R-squared.


# Examples

```jldoctest
julia> Project1.get_r2([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
1.0

julia> Project1.get_r2([1.0, 2.0, 3.0], [2.0, 2.0, 2.0])
0.0

julia> Project1.get_r2([1.0, 2.0, 3.0], [1.0, 2.0, 4.0])
0.5

julia> Project1.get_r2([1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
-3.0
```
"""
function get_r2(y::AbstractVector, y_hat::AbstractVector)
    # check for same vector lengths
    length(y) != length(y_hat) && throw(DimensionMismatch("Vectors y and y_hat have different lengths: y has length $(length(y)) and y_hat has length $(length(y_hat))"))
    # check for empty vectors
    isempty(y) && throw(ArgumentError("y and y_hat must not be empty"))
    # check for missing values
    any(ismissing, y) && throw(MissingException("y has missing values"))
    any(ismissing, y_hat) && throw(MissingException("y_hat has missing values"))
    # check if y is constant
    allequal(y) && throw(ArgumentError("R² is undefined for constant y (all values are $(first(y)))"))
    # return R-squared
    return 1 - sum((y .- y_hat) .^2) / sum((y .- mean(y)) .^2)
end
