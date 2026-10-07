using CSV, DataFrames

"""
    function import_csv(filepath::String) -> DataFrame

Import file from location specified in cofig into a DataFrame

Returns processed listing as DataFrame `df`.

<!-- TODO: add an `# Examples` section with a jldoctest once this function is implemented. -->
"""
function import_csv(filepath::String)
    return CSV.read(filepath, DataFrame)
end

"""
    import_user_input(answers::AbstractDict{Symbol}) -> DataFrame

Turn the user's answers into a one-row table: every key becomes a column, every answer its value.
The columns are sorted alphabetically, so the column order is the same every time.

# Arguments
- `answers::AbstractDict{Symbol}`:  the answers by column name, e.g. from `enter_apartment_data`.

# Throws
- `ArgumentError`   if an answer is `nothing`; the message names the column.

Returns a `DataFrame` with one row; `answers` is not changed.

# Examples
```jldoctest
julia> df = Project1.import_user_input(Dict{Symbol,Any}(:bedrooms => 2, :accommodates => 4));

julia> names(df), nrow(df)
(["accommodates", "bedrooms"], 1)

julia> Project1.import_user_input(Dict{Symbol,Any}(:bedrooms => nothing))
ERROR: ArgumentError: missing answer for bedrooms
```
"""
function import_user_input(answers::AbstractDict{Symbol})
    # take user input dictionary and put it into DataFrame
    for (column, value) in answers
        isnothing(value)  && throw(ArgumentError("missing answer for $column"))   
    end
    # adds values from user input in new columns to 1-row data frame in alphabetical order
    keys_sorted = sort(collect(keys(answers)))
    df_apartment = DataFrame()
    for key in keys_sorted
        df_apartment[!, key] = [answers[key]]
    end
    return df_apartment
end
