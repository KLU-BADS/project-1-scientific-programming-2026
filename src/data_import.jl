using CSV, DataFrames

"""
    function import_csv(filepath::String) -> DataFrame

Import file from location specified in cofig into a DataFrame

Returns processed listing as DataFrame `df`.

```jldoctest

```
"""
function import_csv(filepath::String)
    return CSV.read(filepath, DataFrame)
end
