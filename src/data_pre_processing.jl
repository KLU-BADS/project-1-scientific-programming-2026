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
and to remove rows with zero bedrooms or beds (denominator of ratio features) .

# Arguments
- `df::DataFrame`:              Input data frame.
- `columns::Vector{Symbol}`:    Columns checked for zero values.

Returns the modified DataFrame in place.
"""
function remove_if_zero!(df::DataFrame, columns::Vector{Symbol})

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

Remove rows whose values are outliers according to the configured IQR rule.

# Arguments
- `df::DataFrame`:      Input data frame.
- `rules::NamedTuple`:  Outlier configuration containing method, action, and scale.

Returns the modified DataFrame in place.
"""
function process_outliers!(df::DataFrame, rules::NamedTuple)
    rules.method == :iqr || error("Unknown outlier method :$(rules.method)")
    rules.action == :drop_row || error("Unknown outlier action :$(rules.action)")
    rules.scale in (:raw, :log) || error("Unknown outlier scale :$(rules.scale)")


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
    # 6. give the table back
    return df
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
