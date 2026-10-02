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
    isempty(missing_cols) || error("filter_columns: colummns not found in data: $(join(missing_cols, ", "))")
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

end

"""
    impute_median_by_room_type!(df, col)

Replace missing values in a column with the median value for the same room type.

# Arguments
- `df::DataFrame`:  Input data frame.
- `col::Symbol`:    Column to impute.

Returns the modified DataFrame in place.
"""
function impute_median_by_room_type!(df::DataFrame, col::Symbol)

end

"""
    process_missing!(df, rules)

Apply the configured missing-value rules to each column in sequence.

# Arguments
- `df::DataFrame`:                      Input data frame.
- `rules::Vector{Pair{Symbol,Symbol}}`: Ordered list of column => rule pairs.

Returns the modified DataFrame in place.
"""
function process_missing!(df::DataFrame, rules::Vector{Pair{Symbol,Symbol}})
    for (col, rule) in rules
        if rule == :drop_row

        elseif rule == :fill_zero

        elseif rule == :impute_median_by_room_type

        elseif rule == :impute_median_or_drop_entire_home

        elseif rule == :fill_from_bathrooms_text

        else
            error("Unknown missing value rule :$rule for column :$col")
        end
    end
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
function calculate_distance!(df::DataFrame, rules::NamedTuple, center::NamedTuple)

end
