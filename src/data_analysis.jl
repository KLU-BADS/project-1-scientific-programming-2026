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
    get_fit(fits::AbstractVector, name::Symbol) -> NamedTuple

Find a fitted model by its name.

Each fit is the result of `regression_city()` and carries its spec, including the `name` from `CONFIG.regression_models`. Looking a model up by name keeps working when someone reorders the models; `fits[1]` would silently pick the wrong one.

# Arguments
- `fits::AbstractVector`:   Fits, the `fits` part of the result of `run_analysis_pipeline`.
- `name::Symbol`:           Name of the model, e.g. `:price`.

# Throws
- `ArgumentError` if no fit has this name; the message lists the available names.

Returns the fit with this name.
"""
function get_fit(fits::AbstractVector, name::Symbol)
    # 1. the position of the first fit with this name
    # every fit carries its spec, and the spec carries the name
    i = findfirst(fit -> fit.spec.name == name, fits)

    # 2. a name that does not exist is an error
    # listing the available names helps to find a typo
    if i === nothing
        available = join([":" * string(fit.spec.name) for fit in fits], ", ")
        throw(ArgumentError("no fit named :$name, available names: $available"))
    end

    # 3. return the fit
    return fits[i]
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
    group_importance(df_training, df_test, spec, groups; reference_levels = Dict{Symbol,Any}()) -> DataFrame

How much each group of predictors matters for the model.

The full model is fitted once. For every group it is fitted again without the columns of that group, and the R² (on the model scale, i.e. of the log price for a log model) that is lost on the test set is reported. A large loss means that the group matters. This is more honest than single coefficients, which split credit between related variables and cannot show a categorical variable like the district at all.

# Arguments
- `df_training::DataFrame`:             Training data, the models are fitted on it.
- `df_test::DataFrame`:                 Test data, the R² is measured on it.
- `spec::NamedTuple`:                   Regression specification of the full model, e.g. the `:price` entry of `CONFIG.regression_models`.
- `groups::AbstractVector{<:Pair}`:     Groups as `name => columns`, e.g. `CONFIG.importance_groups`.
- `reference_levels`:                   Reference categories, passed on to [`regression_city`](@ref).

Returns a DataFrame with one row per group and the columns `group` (its name) and `r2_loss`, the largest loss first. A group that does not help can have a tiny negative loss.
"""
function group_importance(df_training::DataFrame, df_test::DataFrame, spec::NamedTuple, groups::AbstractVector{<:Pair}; reference_levels = Dict{Symbol,Any}())
    # 1. the R² of the full model on the test set
    # r2_model_scale is the R² of the log price for a log model, the scale the model is fitted on
    full_fit = regression_city(df_training, spec; reference_levels = reference_levels)
    full_r2 = evaluate_regression(full_fit, df_test).r2_model_scale

    # 2. fit the model again without each group and note the R² that is lost
    group_names = String[]
    losses = Float64[]
    for (name, columns) in groups
        # setdiff removes the columns of the group from the predictors, merge builds a copy of the spec, spec itself stays unchanged (test 5)
        reduced_spec = merge(spec, (predictors = setdiff(spec.predictors, columns), log1p_predictors = setdiff(spec.log1p_predictors, columns)))
        reduced_fit = regression_city(df_training, reduced_spec; reference_levels = reference_levels)
        reduced_r2 = evaluate_regression(reduced_fit, df_test).r2_model_scale
        # the loss is how much worse the model gets without the group
        push!(group_names, String(name))
        push!(losses, full_r2 - reduced_r2)
    end

    # 3. one row per group, the largest loss first
    result = DataFrame(group = group_names, r2_loss = losses)
    return sort(result, :r2_loss; rev = true)
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

"""
    predict_price_range(fit::NamedTuple, df_new::DataFrame; level::Real = 0.8) -> NamedTuple

Predict a price range in euros for each row of `df_new`.

The range is a prediction interval: it covers the price of a share `level` of
comparable apartments (0.8 means 8 out of 10). The recommended price is the median.
For a log price model, the median and the bounds are transformed back with `exp`,
and the mean is the median times `fit.smearing`. The bounds are quantiles, so they
get no smearing. For a model without a log, the median and the mean are the
prediction itself. `df_new` is not changed.

# Arguments
- `fit::NamedTuple`: a fit from `regression_city`, with the fields `spec`, `model` and `smearing`.
- `df_new::DataFrame`: prepared rows with all predictors of `fit.spec`.
- `level::Real = 0.8`: the share of comparable apartments the range should cover
  (`CONFIG.interval_level`).

Returns `(median, mean, lower, upper)`, each a `Vector{Float64}` with one value per row, in euros.
"""
function predict_price_range(fit::NamedTuple, df_new::DataFrame; level::Real = 0.8)
    # 1. turn the rows into the matrix of predictors the model was trained on
    predictor_table = prepare_predictors(df_new, fit.spec)
    
    # 2. predict with a prediction interval: a table with columns prediction, lower, and upper 
    predictions = predict(fit.model, predictor_table; interval = :prediction, level = level)
    
    # 3. take the three columns as plain numbers, still on model's scale
    unconverted_prediction = Float64.(predictions.prediction)
    unconverted_lower = Float64.(predictions.lower)
    unconverted_upper = Float64.(predictions.upper)
    # Float64.() converts every value, because the columns allow missing 
    
    # 4. converts the models answer from log scale to euros 
    if fit.spec.log_scale
        median = exp.(unconverted_prediction)
        lower = exp.(unconverted_lower)
        upper = exp.(unconverted_upper)
        mean = median .* fit.smearing
        # exp of a log prediction is the median; smearing lifts it to the mean
        # the bounds are quantiles, so they need no smearing
    else 
        median = unconverted_prediction
        lower = unconverted_lower
        upper = unconverted_upper
        mean = unconverted_prediction
    end
    # 5. return results
    return (median = median, mean = mean, lower = lower, upper = upper)
end

"""
    occupancy_reference(df_training::DataFrame, district::AbstractString, room_type::AbstractString, rule::NamedTuple; q::Real = 0.5) -> Float64

Occupancy rate of comparable listings in the training data.

Comparable means the same district and the same room type. If there are fewer than `rule.min_count` such listings, all listings of the same room type are used instead. The value is used for the revenue of a new apartment (median, `q = 0.5`) and as the yardstick for "high occupancy" (`q = rule.high_quantile`).

# Arguments
- `df_training::DataFrame`:     Training data with the columns `district`, `room_type` and `occupancy_rate`.
- `district::AbstractString`:   District of the apartment.
- `room_type::AbstractString`:  Room type of the apartment.
- `rule::NamedTuple`:           `CONFIG.occupancy_rule`; `min_count` is the smallest group that is used on its own.
- `q::Real`:                    Quantile to return, 0.5 is the median.

# Throws
- `ArgumentError` if the training data has no listing with this room type.

Returns the occupancy rate as a `Float64`.
"""
function occupancy_reference(df_training::DataFrame, district::AbstractString, room_type::AbstractString, rule::NamedTuple; q::Real = 0.5)
    # 1. the listings with the same district and room type
    # .== compares every row with the value, & keeps the rows where both comparisons are true
    rows = df_training[(df_training.district .== district) .& (df_training.room_type .== room_type), :]

    # 2. too few listings: use all listings of the same room type
    # a group with exactly min_count rows is still used on its own (test 2)
    if nrow(rows) < rule.min_count
        rows = df_training[df_training.room_type .== room_type, :]
    end

    # 3. a room type that does not exist is an error
    # without this check quantile would stop with a less helpful message
    if nrow(rows) == 0
        throw(ArgumentError("no listings with room type \"$room_type\""))
    end

    # 4. the quantile of the occupancy rate, q = 0.5 is the median
    return Float64(quantile(rows.occupancy_rate, q))
end

"""
    assess_listing(current::Real, lower::Real, upper::Real, occupancy::Real, reference::Real) -> NamedTuple

Compare the current price of a listed apartment with its predicted price range.

A price below the range means something different for a fully booked apartment (there is room
to raise it) than for an empty one (the problem is elsewhere), so the occupancy is compared with
the "high" occupancy of comparable listings. A price exactly on a bound counts as inside the range.

# Arguments
- `current::Real`:   The current price per night, in euros.
- `lower::Real`:     Lower end of the price range from `predict_price_range`.
- `upper::Real`:     Upper end of the price range from `predict_price_range`.
- `occupancy::Real`: The listing's occupancy rate, booked nights divided by 365.
- `reference::Real`: The "high" occupancy threshold of comparable listings.

Returns `(status, difference)`: `status` is one of `:underpriced`, `:not_price_problem`, `:in_line`,
`:overpriced` or `:unexplained_premium`, and `difference` is the distance to the nearest bound in
euros, 0 inside the range.
"""
function assess_listing(current::Real, lower::Real, upper::Real, occupancy::Real, reference::Real)
    # 1. below range, well-booked apartment could charge more, an empty one has another problem 
    if current < lower 
        if occupancy >= reference 
            status = :underpriced
        else
            status = :not_price_problem
        end
        difference = lower - current 
        return (status = status, difference = difference) 
    end
    # 2. above range, well-booked apartment has an unexplained premium, an empty one is overpriced
    if current > upper 
        if occupancy >= reference 
            status = :unexplained_premium 
        else 
            status = :overpriced
        end
        difference = current - upper
        return (status = status, difference = difference)
    end 
    # 3. inside range, appropriate pricing
    status = :in_line
    difference = 0.0
    return (status = status, difference = difference)
end 

 """
    significant_terms(fit::NamedTuple; alpha::Real = 0.05) -> Vector{String}

List the terms of a fitted model whose p-value is below `alpha`.

This is the one place for the significance rule, used by the tips and the findings.
The names are written as GLM writes them: `"has_AC"` for a 0/1 column and
`"room_type: Private room"` for a category. The intercept is a term too, so
`"(Intercept)"` can be in the result.

# Arguments
- `fit::NamedTuple`: a fit from `regression_city`, with the field `model`.
- `alpha::Real = 0.05`: the significance level (`CONFIG.significance_level`).

Returns the names of the significant terms as a `Vector{String}`.
"""
function significant_terms(fit::NamedTuple; alpha::Real = 0.05)

    # 1. setting up coefficient table 
    coefficient_table = coeftable(fit.model)
    coefficient_table.rownms
    coefficient_table.pvalcol
    
    # 2. keep the names that have a p-value < alpha
    p_values = coefficient_table.cols[coefficient_table.pvalcol]
    is_significant = p_values .< alpha
    return coefficient_table.rownms[is_significant]

end

"""
    amenity_effects(fit::NamedTuple, df_row::DataFrame, amenities::AbstractVector{Symbol};
                    alpha::Real = 0.05, min_effect_pct::Real = 1.0) -> DataFrame

Price effect of each amenity that the apartment does not have yet.

An amenity is kept only if the apartment lacks it (value 0 in `df_row`), its term is
significant, and its effect is at least `min_effect_pct` percent. For each kept amenity
the price is predicted twice, as the apartment is and with the amenity switched on.
The effects are associations seen in comparable listings, not proven causes.

# Arguments
- `fit::NamedTuple`: a fit from `regression_city`, with the field `model`.
- `df_row::DataFrame`: the prepared one-row table of the apartment.
- `amenities::AbstractVector{Symbol}`: the amenities a host can add (`CONFIG.actionable_amenities`).
- `alpha::Real = 0.05`: the significance level (`CONFIG.significance_level`).
- `min_effect_pct::Real = 1.0`: the smallest effect in percent worth showing (`CONFIG.min_effect_pct`).

Returns a `DataFrame` with the columns `amenity` (Symbol), `change` (euros per night) and
`change_pct` (percent), largest `change` first. It is empty, with the same columns, if
nothing qualifies.
# Throws
- `ArgumentError`: if an amenity in `amenities` is not a column of `df_row`.

# Examples
```julia
fit = regression_city(df_training, spec)
tips = amenity_effects(fit, df_row, CONFIG.actionable_amenities;
                       alpha = CONFIG.significance_level,
                       min_effect_pct = CONFIG.min_effect_pct)
first(tips, 3)   # the three largest effects, as visualize_results shows them
```
"""
function amenity_effects(fit::NamedTuple, df_row::DataFrame, amenities::AbstractVector{Symbol}; alpha::Real = 0.05, min_effect_pct::Real = 1.0)
    # 1. prepare: the significant term names, all term names and the coefficients (in the same order)
    significant_names = significant_terms(fit; alpha = alpha)
    term_names = coefnames(fit.model)
    coefficient = coef(fit.model)
    # 2. choose the amenities: the apartment does not have it yet, its term is significant,
    #    and its effect in percent is at least min_effect_pct
    chosen_amenities = Symbol[]
    for amenity in amenities 
        if df_row[1, amenity] == 0 && string(amenity) in significant_names && 100 * (exp(coefficient[findfirst(==(string(amenity)), term_names)]) -1) >= min_effect_pct
        # checks if an amenity in the apartment is not present (== 0), checks the model if amenity is significant, and checks if the % change in this coefficient is greater than minimum
            push!(chosen_amenities, amenity)
        end
    end 
    # 3. predict the price of the apartment as it is now (the base price)
    base_price = predict_apartment_performance(fit, df_row)[1]
    # 4. for each chosen amenity: switch it on in a copy of the row, predict again,
    #   and record the amenity, the change in euros and the change in percent
    effects = DataFrame(amenity = Symbol[], change = Float64[], change_pct = Float64[])
    for amenity in chosen_amenities 
        row = copy(df_row)
        row[1, amenity] = 1 
        new_price = predict_apartment_performance(fit, row)[1]
        push!(effects, (amenity = amenity,
        change = new_price - base_price,
        change_pct = 100 * (new_price / base_price -1)))
    end
    
    # 5. return the table with the largest change first (an empty table with the same columns if nothing was chosen)
    sort!(effects, :change, rev = true)
    return effects
end