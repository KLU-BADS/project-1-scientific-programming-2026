using DataFrames, Statistics

"""
    filter_columns(df, relevant_columns)

Select only the columns needed for the subsequent modelling steps.

# Arguments
- `df::DataFrame`:                      Input data frame.
- `relevant_columns::Vector{Symbol}`:   Column names to retain.

Returns a new DataFrame containing only the requested columns.
"""
function filter_columns(df::DataFrame, relevant_columns::Vector{Symbol})
    # 1. find the wanted columns that do not exist in the data
    missing_cols = setdiff(relevant_columns, propertynames(df))
    # propertynames(df) = all column names of df as Symbols
    # setdiff(a, b) = everything in a that is not in b
    # so missing_cols holds the wanted columns that the file does not have (empty if all exist)

    # 2. stop with a clear message if a column is missing
    isempty(missing_cols) || error("filter_columns: columns not found in data: $(join(missing_cols, ", "))")
    # isempty(x) is true if the list has no elements
    # cond || error(...) = the error only runs if the condition is false, i.e. if something is missing
    # $(...) puts a value into the text; join(list, ", ") turns the list into "a, b, c"
    # this check runs before anything is changed, so a failed call leaves df untouched (test 6)

    # 3. keep only the wanted columns and return them as a new table
    return select(df, relevant_columns)
    # select (without !) returns a copy, so the original df keeps all its columns (test 3)
    # the columns come out in the order of relevant_columns
end

"""
    format_labels!(df, mapping)

Rename columns in `df` according to a provided name mapping.

# Arguments
- `df::DataFrame`:                  Input data frame.
- `mapping::Dict{Symbol,Symbol}`:   Old column names to new column names.

Returns the modified DataFrame in place.
"""
function format_labels!(df::DataFrame, mapping::Dict{Symbol,Symbol})
    # 1. find the old names in the mapping that do not exist in the table
    missing_cols = setdiff(collect(keys(mapping)), propertynames(df))
    # keys(mapping) = the old names (the left side of each =>)
    # collect(...) turns them into a normal list (Vector)
    # propertynames(df) = all column names of df as Symbols
    # setdiff(a, b) = everything in a that is not in b, so missing_cols holds the old names the data does not have

    # 2. stop with a clear message if an old name is missing
    isempty(missing_cols) || error("format_labels!: columns not found in data: $(join(missing_cols, ", "))")
    # isempty(x) is true if the list has no elements
    # cond || error(...) = the error only runs if the condition is false, i.e. if something is missing
    # $(...) puts a value into the text; join(list, ", ") turns the list into "a, b, c"
    # this check runs before anything is renamed, so a failed call leaves df untouched (test 6)

    # 3. rename the columns in place
    rename!(df, mapping)
    # rename! (with !) changes df itself instead of making a copy (tests 1 and 3)
    # given a Dict(old => new), it renames exactly those columns and leaves the others alone (test 2)
    # with an empty Dict nothing happens (test 4)

    # 4. return the table
    return df
    # the docstring promises "the modified DataFrame", and the test checks out === df
end

"""
    convert_value(value, T)

Convert a single value to type `T` while preserving missing values. Used by set_types!() to convert the values 
    of a column to the requested type. Missing values stay missing, text like `"\$1,250.00"` is cleaned before it is parsed.

# Arguments
- `value`:      Raw value to convert.
- `T::Type`:    Target type.

Returns the converted value. Missing values remain missing.
"""
function convert_value(value, T::Type)
    # 1. missing stays missing
    ismissing(value) && return missing
    # ismissing(value) is true if the value is missing
    # cond && return x = if the condition is true, the function ends here and gives back x
    # so a missing value is returned unchanged (test 4)

    # 2. text: clean it and parse it
    if value isa AbstractString
        # isa checks the type; AbstractString covers String and the special string types CSV.jl uses
        cleaned = replace(strip(value), "\$" => "", "," => "")
        # strip removes spaces at the start and the end
        # replace(text, old => new, ...) swaps every old part for the new one; "\$" is a dollar sign, and "" means "nothing"
        # so "\$1,250.00" becomes "1250.00" (tests 1 and 2)
        isempty(cleaned) && return missing
        # an empty cell has nothing to parse, so it counts as missing (test 5)
        return parse(T, cleaned)
        # parse(Float64, "1250.00") turns the text into the number 1250.0 (tests 1 and 2)
        # parse throws an ArgumentError with the bad text in the message if it is not a number (test 6)
    end

    # 3. everything else (numbers): convert to the target type
    return convert(T, value)
    # convert(Float64, 3) gives 3.0 and convert(Float64, 2.5) stays 2.5 (test 3)
end

"""
    convert_currency!(df, rules, currency)

Convert the monetary columns in `df` from `currency` using the configured exchange rate. Each listed column
is multiplied by the rate for `currency`, an error is raised for unknown currencies or non-positive rates.

# Arguments
- `df::DataFrame`:      Input data frame.
- `rules::NamedTuple`:  Contains the `exchange_rates` lookup (currency => rate) and the `columns` to convert.
- `currency::String`:   Currency code of the source data, used as key in `exchange_rates`.

Returns the modified DataFrame in place.
"""
function convert_currency!(df::DataFrame, rules::NamedTuple, currency::String)
    # 1. stop if the currency of the data has no exchange rate
    haskey(rules.exchange_rates, currency) || error("convert_currency!: unknown currency: $currency")
    # haskey checks if the currency (e.g. "USD") is one of the keys in the exchange rates
    # if not, error(...) stops the function and names the unknown currency
    
    # 2. get the exchange rate and stop if it is zero or negative
    rate = rules.exchange_rates[currency]
    # the rate says how many EUR 1 unit of this currency is worth, e.g. 0.89 for USD
    rate > 0 || error("convert_currency!: exchange rate for $currency must be positive, got $rate")
    # a rate of 0 or below would give zero or negative amounts, so it is not allowed
    
    # 3. stop if a column from the rules does not exist in the table
    missing_cols = setdiff(rules.columns, propertynames(df))
    # setdiff keeps the columns from the rules that the table does not have
    isempty(missing_cols) || error("convert_currency!: columns not found in data: $(join(missing_cols, ", "))")
    # no missing column means we continue, otherwise the error names the missing columns

    # 4. multiply every listed column by the rate into a new vector first, nothing is written yet
    converted = Dict(col => df[!, col] .* rate for col in rules.columns)
    # df[!, col] .* rate multiplies every value of the column by the rate (the dot means "for each value")
    # missing values stay missing, because missing times a number is missing
    # if a column contains text, this fails here and df is still unchanged

    # 5. only now write the converted columns into the table
    for (col, values) in converted
        # go through every converted column: col is its name, values is the new vector
        df[!, col] = values
        # replace the old column with the converted one
        # columns that are not listed in the rules are never touched
    end
    # 6. return the table
    return df
    # the same DataFrame object is returned, so the caller can chain functions in the pipeline
end

"""
    set_types!(df, types)

Convert the selected columns in `df` to the requested Julia types.

# Arguments
- `df::DataFrame`:                  Input data frame.
- `types::Dict{Symbol,DataType}`:   Mapping from column names to target types.

Returns the modified DataFrame in place.
"""
function set_types!(df::DataFrame, types::Dict{Symbol,DataType})
    # 1. find the requested columns that do not exist in the table
    missing_cols = setdiff(collect(keys(types)), propertynames(df))
    # keys(types) are the column names we should convert, e.g. :price and :beds
    # propertynames(df) are the columns that really exist in the table
    # setdiff keeps only the names that are in the first list but not in the second

    # 2. stop with a clear message before anything is changed
    isempty(missing_cols) || error("set_types!: columns not found in data: $(join(missing_cols, ", "))")
    # isempty(...) is true when no column is missing, then `||` skips the error and we continue
    # otherwise error(...) stops the function and names the missing columns
    # because this happens first, a typo in a column name never leaves a half-converted table

    # 3. convert every listed column into a new vector first, nothing is written to the table yet
    converted = Dict(col => Union{Missing,T}[convert_value(v, T) for v in df[!, col]] for (col, T) in types)
    # for (col, T) in types: go through every listed column (col) with its target type (T)
    # for v in df[!, col]: go through every single value (v) of that column
    # convert_value(v, T): clean and convert one value ("$1,712.00" -> 1712.0, missing stays missing)
    # Union{Missing,T}[...]: collect the results in a vector that may contain missing values
    # col => ...: store the new vector under the column name in the dictionary `converted`
    # if one value cannot be converted, convert_value throws an error here and df is still unchanged

    # 4. only now write the converted columns into the table (so a failed conversion leaves df untouched)
    for (col, values) in converted
        # go through every converted column: col is its name, values is the new vector
        
        # 5. replace the old column with the converted one
        df[!, col] = values
        # df[!, col] selects the whole column; assigning to it swaps in the new vector
        # columns that are not in `types` are never touched
    end
    # 6. return the table
    return df
    # the same DataFrame object is returned, so the caller can chain functions in the pipeline
end

"""
    remove_duplicates!(df, check_columns)

Remove duplicate rows based on the columns specified in `check_columns`.

# Arguments
- `df::DataFrame`:                  Input data frame.
- `check_columns::Vector{Symbol}`:  Columns used to identify duplicates.

Returns the modified DataFrame in place.
"""
function remove_duplicates!(df::DataFrame, check_columns::Vector{Symbol})
    # 1. stop if a column from check_columns does not exist in the table
    missing_cols = setdiff(check_columns, propertynames(df))
    # check_columns are the columns that identify a listing, e.g. [:id]
    # propertynames(df) are the columns that really exist in the table
    # setdiff keeps only the names that are in the first list but not in the second

    # 2. stop with a clear message before anything is changed
    isempty(missing_cols) || error("remove_duplicates!: columns not found in data: $(join(missing_cols, ", "))")
    # isempty(...) is true when no column is missing, then `||` skips the error and we continue
    # otherwise error(...) stops the function and names the missing columns
    # because this happens first, a typo in a column name never changes the table

    # 3. remove the repeated rows, comparing only the listed columns
    unique!(df, check_columns)
    # unique! goes through the rows from top to bottom and remembers the values of the check columns
    # the first row with a new combination of values is kept, every later row with the same values is removed
    # example: ids [1, 2, 1, 3, 2] become [1, 2, 3], the rows of the first 1 and the first 2 are kept
    # only the check columns are compared, so two different listings with the same features (other columns) both stay
    # with several check columns, a row is only a repeat if all of them are equal
    # the ! at the end of unique! means that df itself is changed, no copy is made

    # 4. return the table
    return df
    # the same DataFrame object is returned, so the caller can chain functions in the pipeline
end

"""
    remove_if_zero!(df, columns)

Drop rows that contain a zero in at least one of the supplied columns. Used to remove listings without bookings 
and to remove rows with a zero in a denominator column of `ratio_rules` (bedrooms, bathrooms, availability_365).
Rows with missing values are kept, `process_missing!` handles those.

# Arguments
- `df::DataFrame`:              Input data frame.
- `columns::Vector{Symbol}`:    Columns checked for zero values.

Returns the modified DataFrame in place.
"""
function remove_if_zero!(df::DataFrame, columns::Vector{Symbol})
    # 1. find the rows to delete: go through every row and check the given columns
    #    (e.g. a = [1, 0, 3, missing] gives rows_to_delete = [2])
    rows_to_delete = Int[]
    for row in 1:nrow(df)
        for col in columns
            value = df[row, col]
            # missing is checked first because missing == 0 gives missing, not true or false,
            # so the if would fail; empty cells stay here and process_missing! handles them later
            if !ismissing(value) && value == 0
                push!(rows_to_delete, row)
                # one 0 is enough to delete the row, so we stop checking its other columns;
                # without break a row with 0 in two columns would be saved twice
                break
            end
        end
    end

    # 2. delete all saved rows at once and in place (the ! means df itself changes);
    #    deleting inside the loop would shift the row numbers and skip rows
    deleteat!(df, rows_to_delete)

    # 3. return the same table so the pipeline can keep working with it
    return df
end

"""
    parse_bathrooms(text)

Parse a bathroom description such as `"1.5 shared baths"` or `"Half-bath"`. Used to fill missing values in the 
`bathrooms` column from the `bathrooms_text` column.

# Arguments
- `text`:       Raw text to interpret.

Returns the numeric bathroom count, or `missing` if it cannot be parsed.
"""
function parse_bathrooms(text)
    # 1. a missing text cannot be read, so the answer is missing too
    ismissing(text) && return missing
    # cond && return x = return x only if the condition is true, otherwise go on to the next line

    # 2. make everything lowercase so "Half-bath" and "half-bath" are treated the same
    lower_text = lowercase(text)

    # 3. a half bath has no number in the text, so it is handled first
    if occursin("half", lower_text)
        return 0.5
    end
    # occursin(a, b) = true if the word a is somewhere inside the text b

    # 4. split the text into words and stop if there are none (e.g. an empty text "")
    words = split(lower_text)
    # split("1.5 shared baths") = ["1.5", "shared", "baths"], split cuts at the spaces
    isempty(words) && return missing

    # 5. the number is the first word, try to turn it into a number
    number = tryparse(Float64, words[1])
    # tryparse gives the number if the word is one ("1.5" gives 1.5), and nothing if it is not ("bathroom")
    # parse would stop with an error for "bathroom", tryparse lets us decide what to do

    # 6. no number found means missing, otherwise give back the number
    isnothing(number) && return missing
    return number
end

"""
    impute_median_by_room_type!(df, col)

Replace missing values in a column with the median value for the same room type. A room type without any
known value is left untouched, its missing values stay missing.

# Arguments
- `df::DataFrame`:  Input data frame.
- `col::Symbol`:    Column to impute.

Returns the modified DataFrame in place.
"""
function impute_median_by_room_type!(df::DataFrame, col::Symbol)
    # 1. go through every room type that occurs in the table (e.g. "Private room", "Entire home/apt")
    for room_type in unique(df.room_type)
        # unique(list) = the list without repeated values, so every room type is handled once
        # df.room_type is the room_type column, its name is fixed in the data

        # 2. collect the known values of this room type
        known = Float64[]
        # an empty list that will hold the values of col that are not missing
        for row in 1:nrow(df)
            # 1:nrow(df) goes through every row number of the table
            # isequal is used instead of == so that the check also works if a room type itself were missing
            if isequal(df[row, :room_type], room_type) && !ismissing(df[row, col])
                # && = both must be true: the row has this room type and its value is known
                push!(known, df[row, col])
                # push!(list, x) adds x at the end of the list
            end
        end

        # 3. fill the empty cells, but only if there is at least one known value
        if !isempty(known)
            # !isempty(known) = the list has at least one value, the median of an empty list would fail
            middle = median(known)
            # median(list) = the middle value of the list (Statistics is already loaded in this file)
            # the median is used instead of the mean, so one very big flat does not pull the value up
            for row in 1:nrow(df)
                if isequal(df[row, :room_type], room_type) && ismissing(df[row, col])
                    df[row, col] = middle
                    # writes the median into this one empty cell, df itself changes (the ! in the name)
                end
            end
        end
        # with no known value the cells stay missing and nothing breaks (the second line of the spec)
    end

    # 4. return the same table so the pipeline can keep working with it
    return df
    # the docstring promises the modified DataFrame
end

"""
    process_missing!(df, rules)

Apply the configured missing-value rules to each column in sequence. The rules are applied from top to bottom,
so a later rule already sees the table changed by the earlier ones, and a column can appear more than once.

- `:drop_row`:                          delete the rows where the column is missing.
- `:fill_zero`:                         replace missing values with 0.
- `:impute_median_by_room_type`:        replace missing values with the median of the same room type.
- `:impute_median_or_drop_entire_home`: delete the missing rows of entire homes (`CONFIG.entire_home_label`),
                                        fill the other room types with their median.
- `:fill_from_bathrooms_text`:          fill missing values from the `bathrooms_text` column with `parse_bathrooms`,
                                        delete the rows where no number is found ("0 baths" gives 0 and stays).

An error is raised for an unknown rule.

# Arguments
- `df::DataFrame`:                      Input data frame.
- `rules::Vector{Pair{Symbol,Symbol}}`: Ordered list of column => rule pairs.

Returns the modified DataFrame in place.
"""
function process_missing!(df::DataFrame, rules::Vector{Pair{Symbol,Symbol}})
    for (col, rule) in rules
        # rules comes from config.jl, e.g. :price => :drop_row, so no column names are written here
        # (col, rule) splits each pair: col is the column name, rule says what to do with its empty cells
        # the order matters, a later rule already sees the table changed by the earlier rules
        if rule == :drop_row
            # 1. drop_row: delete every row where this column is empty
            rows_to_delete = Int[]
            for row in 1:nrow(df)
                if ismissing(df[row, col])
                    # df[row, col] is one cell, ismissing(x) is true if the cell is empty
                    push!(rows_to_delete, row)
                    # push! adds the row number to the end of the list
                end
            end
            deleteat!(df, rows_to_delete)
            # deleteat! removes these rows from df itself (in place)
            # the row numbers are collected first and deleted together at the end,
            # deleting inside the loop would shift the row numbers and skip rows
            # 1:nrow(df) goes from top to bottom, so the list is already sorted as deleteat! needs it

        elseif rule == :fill_zero
            # 2. fill_zero: write 0 into every empty cell of this column
            for row in 1:nrow(df)
                if ismissing(df[row, col])
                    df[row, col] = 0
                    # writes 0 into this one empty cell, df itself changes (the ! in the name)
                end
            end
            # e.g. reviews_per_month: an empty cell means the listing got no reviews, so 0 is the true value
            # the column holds Float64 numbers (set_types!), so Julia stores the 0 as 0.0 by itself

        elseif rule == :impute_median_by_room_type
            # 3. impute_median_by_room_type: the helper fills the empty cells
            impute_median_by_room_type!(df, col)
            # the helper (#75) uses the median of the same room type, so this branch stays one line
            # a room type without any known value stays missing, the helper does not crash there

        elseif rule == :impute_median_or_drop_entire_home
            # 4. impute_median_or_drop_entire_home: delete empty entire homes, fill the other room types
            rows_to_delete = Int[]
            for row in 1:nrow(df)
                if ismissing(df[row, col]) && isequal(df[row, :room_type], CONFIG.entire_home_label)
                    push!(rows_to_delete, row)
                end
            end
            # && = both must be true: the cell is empty and the listing is an entire home
            # CONFIG.entire_home_label is "Entire home/apt" from config.jl, so a different city file only needs a config change
            # isequal is used like in impute_median_by_room_type!, it also works if a room type itself were missing
            deleteat!(df, rows_to_delete)
            # deleteat! removes these rows from df itself, same as in drop_row
            impute_median_by_room_type!(df, col)
            # the remaining empty cells belong to other room types, the helper fills them with their median
            # deleting first matters: if the helper ran first, it would also fill the entire homes
            # e.g. most missing bedrooms are private rooms and 96% of them have 1 bedroom, entire homes vary too much

        elseif rule == :fill_from_bathrooms_text
            # 5. fill_from_bathrooms_text: read the number from the bathroom text, then delete rows that still have none
            for row in 1:nrow(df)
                if ismissing(df[row, col])
                    df[row, col] = parse_bathrooms(df[row, :bathrooms_text])
                end
            end
            # parse_bathrooms (#74) reads one text, e.g. "1.5 shared baths" gives 1.5 and "Half-bath" gives 0.5
            # if the text has no number or is empty too, it gives missing back and the cell stays empty
            # :bathrooms_text is written here because this rule is about exactly that column, its name says so
            rows_to_delete = Int[]
            for row in 1:nrow(df)
                if ismissing(df[row, col])
                    push!(rows_to_delete, row)
                end
            end
            deleteat!(df, rows_to_delete)
            # rows whose bathrooms are still empty cannot be guessed, so they are deleted like in drop_row
            # "0 baths" gives 0.0 and is not deleted here, remove_if_zero! handles zeros later in the pipeline

        else
            error("Unknown missing value rule :$rule for column :$col")
        end
    end

    # 6. return the table
    return df
    # the docstring promises the modified DataFrame, the stub did not return anything yet
end

"""
    process_outliers!(df, rules)

Remove rows whose values are outliers according to the configured IQR rule. For every column in `rules.columns`
the normal range is Q1 - `iqr_multiplier` * IQR up to Q3 + `iqr_multiplier` * IQR, where IQR = Q3 - Q1.
A row is removed if it lies outside this range in at least one of the columns. Every column is judged on the
full table first, then all flagged rows are removed together. With `scale = :log` the check uses the log of
the values, the values in the table are not changed. An error is raised if a column has missing values,
or values of 0 or below on the log scale.

# Arguments
- `df::DataFrame`:      Input data frame.
- `rules::NamedTuple`:  Outlier configuration containing the `columns` to check, `method` (:iqr),
                        `iqr_multiplier`, `scale` (:raw or :log) and `action` (:drop_row).

Returns the modified DataFrame in place.
"""
function process_outliers!(df::DataFrame, rules::NamedTuple)
    rules.method == :iqr || error("Unknown outlier method :$(rules.method)")
    rules.action == :drop_row || error("Unknown outlier action :$(rules.action)")
    rules.scale in (:raw, :log) || error("Unknown outlier scale :$(rules.scale)")

    # 1. make an empty list for the row numbers that will be deleted
    rows_to_delete = Int[]
    # Int[] is an empty list that can only hold whole numbers (row numbers)
    # rows are only saved here and deleted at the very end (step 6)

    # 2. check every column from the config one after another
    for col in rules.columns
        # rules.columns comes from config.jl, e.g. [:price, :estimated_revenue], so no names are written here
        # df[!, col] is the whole column with that name

        # 3. stop with a clear message if the column has empty cells
        any(ismissing, df[!, col]) && error("process_outliers!: column :$col has a missing value")
        # any(ismissing, x) is true if at least one value in x is missing
        # cond && error(...) = the error only runs if the condition is true
        # an empty cell cannot be compared with a number, process_missing! should have removed them before

        # 4. copy the values and take the log if the config says so
        numbers = Float64.(df[!, col])
        # Float64.(x) turns every value into a decimal number and makes a copy, so the table itself is not changed
        if rules.scale == :log
            any(number -> number <= 0, numbers) && error("process_outliers!: column :$col has a value of 0 or below, log is not defined")
            # number -> number <= 0 is a small function that checks one value, any(...) checks it for all values
            # the log of 0 or of a negative number does not exist, so we stop before log would fail
            numbers = log.(numbers)
            # log. (with a dot) takes the log of every value in the list
            # prices are very skewed (many cheap rooms, few very expensive homes), the log makes them more even,
            # so only the truly odd listings are flagged; the euros in the table stay as they are
        end

        # 5. work out the normal range and save every row outside it
        q1 = quantile(numbers, 0.25)
        q3 = quantile(numbers, 0.75)
        iqr = q3 - q1
        # quantile(x, 0.25) is the value a quarter of the way up the sorted list (Q1), 0.75 three quarters up (Q3)
        # the IQR is the distance between them, so the width of the middle half of the data
        lower = q1 - rules.iqr_multiplier * iqr
        upper = q3 + rules.iqr_multiplier * iqr
        # the multiplier (1.5) comes from the config, a bigger number would remove fewer rows
        # e.g. prices [100, 110, ..., 180, 10000] on the raw scale give Q1 = 122.5, Q3 = 167.5, IQR = 45,
        # so the normal range is 55 to 235 and only the row with 10000 is outside
        for row in 1:nrow(df)
            if (numbers[row] < lower || numbers[row] > upper) && !(row in rows_to_delete)
                push!(rows_to_delete, row)
            end
        end
        # 1:nrow(df) goes through every row number; || means "or", so too low and too high both count
        # !(row in rows_to_delete) makes sure a row flagged by both columns is saved only once
        # push! adds the row number to the end of the list
    end

    # 6. delete all saved rows at once
    sort!(rows_to_delete)
    deleteat!(df, rows_to_delete)
    # sort! puts the row numbers in order, because deleteat! needs them sorted
    # deleteat! removes the rows from df itself (in place)
    # deleting only now means every column was judged on the full table; deleting inside the loop
    # would change Q1 and Q3 for the next column and shift the row numbers

    # 7. return the table
    return df
    # the docstring promises the modified DataFrame, so the pipeline can continue with it
end

"""
    remove_implausible!(df, rules)

Remove rows whose size values are impossible, e.g. 50 bedrooms for 2 guests. A row is kept only if
`df[i, rule.column] <= rule.factor * df[i, rule.max_of] + rule.offset` holds for every rule.
Every rule is judged on the full table first, then all flagged rows are removed together.
An error is raised if a column used in a rule has missing values.

# Arguments
- `df::DataFrame`:                  Input data frame.
- `rules::Vector{<:NamedTuple}`:    Rules, each with `column` (the value that is checked), `max_of` (the column that
                                    sets the limit), `factor` and `offset`.

Returns the modified DataFrame in place.
"""
function remove_implausible!(df::DataFrame, rules::Vector{<:NamedTuple})
    # 1. make a list that remembers for every row if it has to be deleted
    to_delete = falses(nrow(df))
    # falses(n) is a list of n times false, one entry per row; false means the row stays for now
    # rows are only flagged here and deleted at the very end (step 5)

    # 2. check every rule one after another
    for rule in rules
        # rules comes from config.jl (CONFIG.plausibility_rules), so no column names are written here
        # df[!, name] is the whole column with that name

        # 3. stop with a clear message if one of the two columns has empty cells
        any(ismissing, df[!, rule.column]) && error("remove_implausible!: column :$(rule.column) has a missing value")
        any(ismissing, df[!, rule.max_of]) && error("remove_implausible!: column :$(rule.max_of) has a missing value")
        # any(ismissing, x) is true if at least one value in x is missing
        # cond && error(...) = the error only runs if the condition is true
        # an empty cell cannot be compared with a number, process_missing! should have removed them before

        # 4. flag every row that breaks the rule
        for row in 1:nrow(df)
            limit = rule.factor * df[row, rule.max_of] + rule.offset
            # the limit of this row, e.g. 1.0 * 2 guests + 0.0 = 2.0 bedrooms at most
            if df[row, rule.column] > limit
                to_delete[row] = true
                # a row above the limit is flagged; a value exactly on the limit stays because we only flag if it is greater
            end
        end
        # 1:nrow(df) goes through every row number
        # a row flagged by two rules stays flagged once, setting true again changes nothing
    end

    # 5. delete all flagged rows at once
    deleteat!(df, findall(to_delete))
    # findall(to_delete) gives the row numbers where the entry is true, e.g. [3, 7]
    # deleteat! removes the rows from df itself (in place)
    # deleting only now means every rule was judged on the full table and the row numbers did not shift in the loop

    # 6. return the table
    return df
    # the docstring promises the modified DataFrame, so the pipeline can continue with it
end

"""
    compute_caps(df::DataFrame, rule::NamedTuple) -> Dict{Tuple{String,Symbol},Float64}

Compute the upper limit (cap) of each size column for each room type.

The cap is the quantile of the room type's own values, rounded down to a whole number. It is computed on the training data only; the result is saved as `fitted.caps` and reused for the user's input by `cap_values!`.

# Arguments
- `df::DataFrame`: Cleaned listings table.
- `rule::NamedTuple`: Cap rule with the fields `columns` (the columns to cap), `group_by` (the column that defines the groups, `:room_type`) and `quantile` (for example 0.995).

Returns a Dict keyed by `(room_type, column)`, e.g. `("Entire home/apt", :accommodates) => 12.0`. The table is not changed.
"""
function compute_caps(df::DataFrame, rule::NamedTuple)
    # 1. the caps are collected in a Dict
    # the key is (room type, column) and the value is the cap
    caps = Dict{Tuple{String,Symbol},Float64}()

    # 2. go through the listings of one room type at a time
    # groupby splits the table into one sub-table per room type
    for group in groupby(df, rule.group_by)
        # 3. the room type of this sub-table
        # all rows of a group have the same value, so the first row is enough
        room_type = String(group[1, rule.group_by])

        # 4. one cap per column
        for column in rule.columns
            # 5. the quantile of the room type's values, rounded down
            # floor makes the cap a whole number, so an Int column stays an Int column when it is capped
            caps[(room_type, column)] = floor(quantile(group[!, column], rule.quantile))
        end
    end

    # 6. return all caps
    return caps
end

"""
    cap_values!(df::DataFrame, caps::AbstractDict, rule::NamedTuple) -> DataFrame

Limit the size columns of each listing to the cap of its room type.

A value above the cap becomes the cap; a value below or exactly on the cap stays. No row is removed. The same function is used for the training data and for the user's input.

# Arguments
- `df::DataFrame`: Listings table with the columns of the rule.
- `caps::AbstractDict`: Caps from `compute_caps`, keyed by `(room_type, column)`.
- `rule::NamedTuple`: Cap rule with the fields `columns` (the columns to cap) and `group_by` (the column with the room type).

Returns the modified DataFrame in place. Throws an `ArgumentError` if a room type has no cap.
"""
function cap_values!(df::DataFrame, caps::AbstractDict, rule::NamedTuple)
    # 1. go through the rows one by one
    for i in 1:nrow(df)
        # 2. the room type of this row
        # the caps are looked up by room type and column
        room_type = String(df[i, rule.group_by])

        # 3. check every column of the rule
        for column in rule.columns
            # 4. the key of this cap
            key = (room_type, column)

            # 5. a room type without a cap is an error
            # at prediction time this means the room type was not in the training data
            if !haskey(caps, key)
                throw(ArgumentError("no cap for room type \"$room_type\" and column $column"))
            end

            # 6. only a value above the cap is lowered
            # the caps are whole numbers, so an Int column stays an Int column
            if df[i, column] > caps[key]
                df[i, column] = caps[key]
            end
        end
    end

    # 7. return the modified table
    return df
end

"""
    format_dummies!(df, rules)

Create dummy variables for categorical columns according to the configured rules.

# Arguments
- `df::DataFrame`:      Input data frame.
- `rules::NamedTuple`:  Contains the reference to source column `source` containing unformatted dummy variable,
                        dummy variable name `target`, 
                    
                        (set of) keywords used in the listings.csv file `keywords`, and
                        the optional flag `delete` to delete column after dummy conversion 

Returns the modified DataFrame in place.
"""
function format_dummies!(df::DataFrame, rules::NamedTuple)
        # 1. get text column we search in 
    texts = df[!,rules.source]
    # this assigns all rows from the source columns (from dummy rules) from the dataframe to texts
        # 2. lowercase everything
    lower_texts = lowercase.(texts)
    # creates a lowercased version of the texts variable
        # 3. check if text contains keyword (boolean)
    found_vector = Bool[]
    #creates a new list/vector for booleans which will be used to push true/false statements
    for description in lower_texts
        found = false 
        #for loop for each listing, boolean found is used as a tracker to ensure that found statements are only entered into the array once 
        for word in rules.keywords
            # for loop for each keyword within the descriptions
            if occursin(word, description)
                # if statement that looks if relevant words occur in each listing
                found = true
                # the boolean changes to true and ensures that each listing is pushed once per rule
                # e.g.: if listing uses term washer and free washer, this boolean becomes true after first time, so length for each listing is correct (only once, not 2 because "washer" and "free washer" exists)
            end
        end
        push!(found_vector, found)
        #this pushes the true or false statements into a list and stores it for later use within the function
    end 
        # 4. turn boolean into 1/0 (= true/false) + store this as new column
    dummy_values = Int.(found_vector)
        # converts every boolean in found_vector into respective dummy, i.e.: true = 1, false = 0 
    df[!, rules.target] = dummy_values
    # all rows in column rule.target in dataframe are set equal to dummy values
        # 5. delete original columns 
    if rules.delete == true && rules.source != rules.target
        select!(df, Not(rules.source))
        #select = says which columns to keep and Not says which ones to remove, so from df keep everything, but not rule.source
    end
    # 6. return the table
    return df
    # the docstring promises the modified DataFrame, so the pipeline can continue with it
end

"""
    calculate_ratio!(df, rules)

Compute a ratio feature from two columns using the configured rule.

# Arguments
- `df::DataFrame`: Input data frame.
- `rules::NamedTuple`: Rule describing the numerator, denominator, and naming.

Returns the modified DataFrame in place.
"""
function calculate_ratio!(df::DataFrame, rules::NamedTuple)
    # 1. get the numerator column
    numerators = df[!, rules.numerator]
    # assigns all rows from the numerator columns in the df dataframe to the numerators variable

    # 2. get the denominator: a column OR a fixed number
    if rules.denominator isa Symbol
        denominators = df[!, rules.denominator]
    else
        denominators = rules.denominator
    end
    # determines whether denominator is a column or just a fixed number (e.g.: 365), then assigns that to the denominators variable to ensure division is correct

    # 3. stop with an error if the denominator has a 0 or a missing value
    if any(ismissing, denominators)
        error("denominator $(rules.denominator) has a missing value")
    elseif any(denominator -> denominator == 0, denominators)
        error("denominator $(rules.denominator) contains a value equal to 0")
    end
    # Determines if there are any errors in the denominator columns which would stop the function from working. 
    # Stops the function and throws the associated error message if the error exists. 

    # 4. divide row by row and store the result as the new column
    ratios = numerators./denominators 
    df[!, rules.target] = ratios
    # Divides numerators by the correct denominators and assigns the ratios variable(so calculated ratios) to the associated new columns in rules.target
    # 5. delete the source columns if rule.delete is true
    if rules.delete == true
        select!(df, Not(rules.numerator))
        if rules.denominator isa Symbol
            select!(df, Not(rules.denominator))
        end
    end
    # Deletes old columns according to certain conditions
        # Deletes numerators if the rules.delete is true
        # Only deletes rules.denominator columns if the data within the columns are symbols (so refers to a column, say :beds) (and not a fixed number)
end

"""
    calculate_distance!(df, rules, center)

Compute a distance feature relative to the configured city center.

# Arguments
- `df::DataFrame`: Input data frame.
- `rules::NamedTuple`: Distance rule configuration.
- `center::NamedTuple`: Coordinates of the city center.

Returns the modified DataFrame in place.
"""
function calculate_distance!(df::DataFrame, rule::NamedTuple, center::NamedTuple)
# 1. get the latitude and longitude columns of the listings
    lats = df[!, rule.source_columns.latitude]
    lons = df[!, rule.source_columns.longitude]
    # Assigns all rows in the column rule.source_columns.latitude/longitude from the df datafram to their respective variables 
    # 2. convert all coordinates from degrees to radians
    lats_rad = deg2rad.(lats)
    longs_rad = deg2rad.(lons)
    center_lat_rad = deg2rad(center.latitude)
    center_lon_rad = deg2rad(center.longitude)
    # Converts the coordinates of the individual listing locations and city center into radians (i.e.: sin, cos)

    # 3. apply the haversine formula to get the distance in km
    dlat = lats_rad .- center_lat_rad 
    dlon = longs_rad .- center_lon_rad
    a_part_lat = sin.(dlat./2).^2 
    a_part_lon = cos.(lats_rad).*cos.(center_lat_rad).*sin.(dlon./2).^2
    a = a_part_lat.+a_part_lon
    c = 2 .*asin.(sqrt.(a))
    earth_radius_km = 6371.0
    distances = earth_radius_km .* c

    # 4. store the distances as the new column
    df[!, rule.target] = distances

    # 5. delete the latitude and longitude columns if rule.delete is true
    if rule.delete == true  
        select!(df, Not(rule.source_columns.latitude))
        select!(df, Not(rule.source_columns.longitude))
    end
    return df
end

"""
    kept_categories(df, rule) -> Vector{String}

Return the categories of the column named in `rule.column` that occur in at least `rule.min_count` rows.

Run once on the training data. The result is saved (as `fitted.kept_districts`) and passed to
`group_rare_categories!`, both in training and at prediction time, so a user's apartment is
grouped exactly like the training data. The table itself is not changed.

# Arguments
- `df::DataFrame`:     The cleaned listings data.
- `rule::NamedTuple`:  The category rule, e.g. `CONFIG.category_rule`, with the fields
                       `column` (the column to count, e.g. `:district`) and
                       `min_count` (the minimum number of rows a category needs to be kept).

Returns the kept category names as a `Vector{String}`, in order of first appearance in `df`.

# Examples
```jldoctest
julia> using DataFrames

julia> df = DataFrame(district = ["Plaka", "Plaka", "Plaka", "Kolonaki", "Kolonaki", "Exarchia"]);

julia> rule = (column = :district, min_count = 2, other_label = "_other");

julia> Project1.kept_categories(df, rule)
2-element Vector{String}:
 "Plaka"
 "Kolonaki"
```
"""
function kept_categories(df::DataFrame, rule::NamedTuple)
    # 1. count the rows per category of the column named in the rule
    grouped = groupby(df, rule.column)
    counts = combine(grouped, nrow => :count)
    # 2. keep only the categories with at least rule.min_count rows
    kept_rows = counts[counts.count .>= rule.min_count, :]
    # 3. return their names as a list
    return String.(kept_rows[!, rule.column])
end

"""
    group_rare_categories!(df, rule, kept) -> df

Replace every value of the column named in `rule.column` that is not in `kept` with `rule.other_label`.

Rare categories are pooled into one group, so the regression estimates one effect for them instead
of unreliable effects from a handful of listings. No rows are removed and no other column is changed.

# Arguments
- `df::DataFrame`:          The listings data, or the one-row table of a user's apartment.
- `rule::NamedTuple`:       The category rule, e.g. `CONFIG.category_rule`, with the fields
                            `column` (the column to group, e.g. `:district`) and
                            `other_label` (the replacement text, e.g. `"_other"`).
- `kept::Vector{String}`:   The categories to keep unchanged, as returned by `kept_categories`
                            on the training data.

Returns the modified DataFrame in place.

# Examples
```jldoctest
julia> using DataFrames

julia> df = DataFrame(district = ["Plaka", "Kolonaki", "Exarchia"]);

julia> rule = (column = :district, min_count = 2, other_label = "_other");

julia> Project1.group_rare_categories!(df, rule, ["Plaka", "Kolonaki"]);

julia> df.district
3-element Vector{String}:
 "Plaka"
 "Kolonaki"
 "_other"
```
"""
function group_rare_categories!(df::DataFrame, rule::NamedTuple, kept::Vector{String})
    # 1. get the category column named in the rule
    categories = df[!, rule.column]
    # 2. for every value: keep it if it is in kept, otherwise replace it with rule.other_label
    new_values = String[]

    for cat in categories
        if cat in kept
            push!(new_values, cat)
        else
            push!(new_values, rule.other_label)
        end
    end
    # creates a new list to which either the actual district name $cat is added, or the rule other label (just adds "_Other")
    # 3. store the new values back in the column
    df[!, rule.column] = new_values
    # Assigns elements of new values to the dataframe for all rows in the rule column(s)
    # 4. give the table back
    return df
end 