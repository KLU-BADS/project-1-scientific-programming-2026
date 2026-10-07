using CSV, DataFrames

"""
    import_csv(filepath::String) -> DataFrame

Read a CSV file into a DataFrame, e.g. the `<city>_listings.csv` file at `CONFIG.filepath`.
The data is returned as it is in the file; all processing happens in the later steps of `run_training_pipeline`.

# Arguments
- `filepath::String`:   path to the CSV file.

# Throws
- `ArgumentError`   if there is no file at `filepath`.

Returns the file's content as a `DataFrame`, one row per line and one column per field of the header.

# Examples
```jldoctest
julia> path = tempname() * ".csv";

julia> write(path, "id,price,room_type\\n1,50,Private room\\n2,80,Entire home/apt\\n");

julia> df = Project1.import_csv(path);

julia> size(df)
(2, 3)

julia> names(df)
3-element Vector{String}:
 "id"
 "price"
 "room_type"
```
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
