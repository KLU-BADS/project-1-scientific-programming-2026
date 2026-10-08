using CSV, DataFrames, JSON3, HTTP

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
        isnothing(value) && throw(ArgumentError("missing answer for $column"))   
    end
    # adds values from user input in new columns to 1-row data frame in alphabetical order
    keys_sorted = sort(collect(keys(answers)))
    df_apartment = DataFrame()
    for key in keys_sorted
        df_apartment[!, key] = [answers[key]]
    end
    return df_apartment
end


# ------------------------------------------------------------------------------------------
# OPTIONAL: address lookup (geocode_address, parse_geocode_response, ask_text)
# Kept after the feature freeze so the team can still decide to use it instead of
# typing coordinates. If it is NOT used in the final version, remove ALL of this:
#   1. geocode_address and parse_geocode_response (here, data_import.jl)
#   2. ask_text (user_interface.jl)
#   3. their test sets in test/runtests.jl ("ask_text", "parse_geocode_response", "geocode_address")
#   4. HTTP and JSON3 from Project.toml ([deps] and [compat]) and from the `using` line at the top of this file
#   5. the `geocoding` entry in src/config.jl
#   6. their function cards and index rows in the team guide
# Then run `] resolve` and `] test` to check that nothing else used them.
# ------------------------------------------------------------------------------------------

"""
    geocode_address(address, city, bounds; config = CONFIG.geocoding) -> NamedTuple or nothing

Look up the coordinates of an address with OpenStreetMap's address search (Nominatim).

Only matches inside `bounds` are accepted, so an address in another city with the same street name is not found.
Nominatim's rules: at most one request per second, no automatic repeats, and a User-Agent that names our program
(`config.user_agent`). Always show the found `display_name` to the user and ask whether it is the right address.

# Arguments
- `address::AbstractString`:  the address as the user typed it, e.g. `"Ermou 10"`.
- `city::AbstractString`:     the city name, added to the search, e.g. `CONFIG.city`.
- `bounds::NamedTuple`:       the area the result must lie in: `(lat_min = …, lat_max = …, lon_min = …, lon_max = …)`,
                              e.g. the extremes of the training data.
- `config::NamedTuple`:       `url`, `user_agent`, `country_code` and `timeout` (default `CONFIG.geocoding`).

Returns `(latitude = …, longitude = …, display_name = …)`, or `nothing` if there is no match, no internet connection
or any other error. The caller then falls back to entering coordinates.
"""
function geocode_address(address::AbstractString, city::AbstractString, bounds::NamedTuple;
                         config::NamedTuple = CONFIG.geocoding)
    # 1. the search area as Nominatim expects it: "left,top,right,bottom" (longitude first)
    search_area = "$(bounds.lon_min),$(bounds.lat_max),$(bounds.lon_max),$(bounds.lat_min)"
    # 2. the search settings, sent as part of the web address
    search_settings = [
        "q"            => "$address, $city",      # what to search for
        "format"       => "json",                 # answer as JSON text
        "limit"        => "1",                    # only the best match
        "countrycodes" => config.country_code,    # only this country, e.g. "gr"
        "viewbox"      => search_area,            # the search area ...
        "bounded"      => "1",                    # ... and only results inside it
    ]
    # 3. send the request; any problem (no internet, timeout, server error) gives nothing
    try
        response = HTTP.get(config.url;
                            query = search_settings,
                            headers = ["User-Agent" => config.user_agent],
                            readtimeout = config.timeout,
                            retry = false)        # Nominatim's rules: no automatic repeats
        # 4. the answer arrives as bytes; String(...) turns it into text for the parser
        return parse_geocode_response(String(response.body))
    catch
        return nothing
    end
end

"""
    parse_geocode_response(response_text::AbstractString) -> NamedTuple or nothing

Read the answer of the address search (Nominatim, JSON format) and take the first match.

Nominatim answers with a JSON list of matches; each match has the fields `lat`, `lon` and `display_name`.
`lat` and `lon` are sent as text, so they are turned into numbers here.

# Arguments
- `response_text::AbstractString`:  the answer of the address search as text.

# Throws
- an error if `response_text` is not valid JSON.

Returns `(latitude = …, longitude = …, display_name = …)` for the first match, or `nothing` if the list is empty
(no address found).
"""
function parse_geocode_response(response_text::AbstractString)
    # 1. turn the JSON text into a list of matches
    matches = JSON3.read(response_text)
    # 2. an empty list means: no address found
    isempty(matches) && return nothing
    # 3. the first match is the best one
    best_match = matches[1]
    # 4. lat and lon arrive as text, e.g. "37.97", so they are turned into numbers
    latitude = parse(Float64, best_match.lat)
    longitude = parse(Float64, best_match.lon)
    # 5. the full address as Nominatim found it, to show the user for confirmation
    display_name = String(best_match.display_name)
    return (latitude = latitude, longitude = longitude, display_name = display_name)
end
