using Project1
using Test
using DataFrames

# Every @testset that fails will be reported individually, so give them
# names that tell you what broke.

 
# Functions that are not exported are reached with the prefix P.
# Only the three pipelines are exported, so every other function is called as P.name(...).
const P = Project1
 
# Every @testset that fails is reported individually, so give them names that tell you what broke.
#
# How to fill a test set:
#   1. build a tiny made-up DataFrame (never the real listings.csv, except in the last test set),
#   2. run the function on it,
#   3. check the result with @test, and the errors with @test_throws ErrorException.
# Then delete the @test_broken placeholder of that test set.
#
# @test_broken false marks a test set as "not written yet": it shows up as Broken in the test
# output, but it does not make the test run fail. An empty test set would pass silently instead.
 
@testset "Project1.jl" begin
 
    # ------------------------------------------------------------------------------------------
    # data_import.jl
    # ------------------------------------------------------------------------------------------
 
    @testset "import_csv" begin
        # - a small CSV file written to a temporary file (tempname()) is read into a DataFrame
        #   with the right number of rows and columns
        # - a path that does not exist throws an error
        @test_broken false
    end
 
    # ------------------------------------------------------------------------------------------
    # data_pre_processing.jl
    # ------------------------------------------------------------------------------------------
 
    @testset "convert_value / set_types!" begin
        # - "\$1,250.00" becomes 1250.0 (currency sign and thousands separator are removed)
        # - an Int becomes a Float64, missing stays missing
        # - text that is not a number ("abc") throws an ArgumentError
        # - set_types! converts every listed column, missing values stay missing,
        #   and the column type is Union{Missing,Float64}
        @test_broken false
    end
 
    @testset "filter_columns" begin
        # 1. build a tiny made-up table for the test
        df = DataFrame(id = [1, 2, 3], price = [100.0, 90.0, 50.0], junk = ["a", "b", "c"])
        # DataFrame(name = values, ...) builds a table by hand: 3 rows, 3 columns
        # "junk" stands for a column we do NOT want to keep

        # 2. normal case: only the listed columns are left, the values are unchanged
        out = P.filter_columns(df,[:id, :price])
        # runs our function; P. is needed because the tests reach the package functions through P = Project1
        # [:id, :price] is the list of columns to keep, written as Symbols like in CONFIG.relevant_columns
        @test names(out) == ["id", "price"]
        # names(out) gives the column names as Strings, so we compare with Strings, not Symbols
        # this checks that "junk" is gone and that only the two wanted columns are left, in this order
        @test out.price == [100.0, 90.0, 50.0]
        # out.price is the price column of the result; the values must be exactly the same as before
        @test nrow(out) == 3
        # nrow = number of rows; filtering columns must never remove or add rows        

        # 3. nothing else changed: the original keeps all its columns and is not linked to the copy
        @test names(df) == ["id", "price", "junk"]
        # the original table must still have all 3 columns, because filter_columns returns a copy
        out[1, :price] = 999.0
        # changes the price in row 1 of the RESULT to 999.0 (out[row, column] = new value)
        @test df.price[1] == 100.0
        # the original still has 100.0, so result and original are separate tables
        # changing the result must not change the original, otherwise it would not be a real copy

        # 4. edge case: a single column
        @test names(P.filter_columns(df, [:id])) == ["id"]
        # the smallest useful list has only one column; the function must still return a table with just that column

        # 5. error case: a wanted column that does not exist stops with an error that names it
        @test_throws ErrorException P.filter_columns(df, [:id, :nonexistent])
        # passes only if the call stops with an error(...); :nonexistent is not in df, so it must fail
        @test_throws "nonexistent" P.filter_columns(df, [:id, :nonexistent])
        # a String as the first argument of @test_throws checks that the error message contains that word
        # so the message must name the missing column and not just say "error"

        # 6. a failed call leaves the table untouched
        @test names(df) == ["id", "price", "junk"]
        # after the two failed calls above, df must still be exactly as before
        # this works because the check runs before select in the function
    end 
    
    
    @testset "format_labels!" begin
        # 1. normal case: one column gets a new name
        df = DataFrame(id = [1, 2, 3], host_is_superhost = [true, false, true], price = [100.0, 90.0, 50.0])
        # tiny made-up table that uses the raw column names
        out = P.format_labels!(df, Dict(:host_is_superhost => :is_superhost))
        # Dict(old => new) is the rulebook; out is whatever the function returns
        @test names(df) == ["id", "is_superhost", "price"]
        # df itself was renamed (in place), and the order of the columns stayed the same
        @test df.is_superhost == [true, false, true]
        # the data under the new name is still the old data
        @test out === df
        # === checks that out is the very same table object, not a copy

        # 2. nothing else changed
        @test df.price == [100.0, 90.0, 50.0]
        # a column that is not in the mapping keeps its name and its values
        @test nrow(df) == 3
        # no rows were lost

        # 3. all three renames from the config at once
        df2 = DataFrame(id = [1, 2], host_is_superhost = [true, false], number_of_reviews = [10, 20], estimated_revenue_l365d = [500.0, 800.0])
        # a fresh table with the 3 raw names that CONFIG.label_mapping renames, plus one column (id) that must stay
        P.format_labels!(df2, Dict(:host_is_superhost => :is_superhost, :number_of_reviews => :number_ratings, :estimated_revenue_l365d => :estimated_revenue))
        # the same 3 renames as in config.jl, written out so the test does not break if someone edits the config
        @test names(df2) == ["id", "is_superhost", "number_ratings", "estimated_revenue"]
        # all three got their new names, id kept its name, and the order of the columns did not change
        @test df2.number_ratings == [10, 20]
        # the data under a renamed column is still the old data

        # 4. edge case: empty mapping
        df3 = DataFrame(a = [1, 2], b = [3, 4])
        # another fresh table
        P.format_labels!(df3, Dict{Symbol,Symbol}())
        # Dict{Symbol,Symbol}() is an empty Dict with the types the function expects
        @test names(df3) == ["a", "b"]
        # an empty rulebook renames nothing

        # 5. error case: a name in the mapping is not in the table
        df4 = DataFrame(a = [1, 2], b = [3, 4])
        @test_throws ErrorException P.format_labels!(df4, Dict(:nonexistent => :x))
        # the function must stop with an error
        @test_throws "nonexistent" P.format_labels!(df4, Dict(:nonexistent => :x))
        # the message must name the missing column, so the user knows what is wrong

        # 6. a failed call leaves the table untouched
        @test_throws ErrorException P.format_labels!(df4, Dict(:a => :x, :nonexistent => :y))
        # one valid rename (a => x) and one invalid key in the same call
        @test names(df4) == ["a", "b"]
        # nothing was renamed, not even the valid part, because the check runs before any change
    end

    @testset "convert_currency!" begin
        # rates = Dict("EUR" => 1.0, "XYZ" => 0.5)  (a made-up currency for the test)
        # - 100.0 in "XYZ" becomes 50.0: amount in EUR = amount × rate
        # - "EUR" leaves the values unchanged
        # - every column in the list is converted, other columns are not
        # - missing stays missing
        # - a currency that is not in rates throws an error with a clear message
        # - a rate of 0 or below throws an error
        @test_broken false
    end
 
    @testset "remove_duplicates! / remove_if_zero!" begin
        # - remove_duplicates! keeps the first row of every id
        # - remove_if_zero! removes rows with 0, leaves missing values alone
        # - a 0 in any of several listed columns removes the row
        @test_broken false
    end
 
    @testset "parse_bathrooms" begin
        # - "1 bath" -> 1.0, "1.5 shared baths" -> 1.5, "0 baths" -> 0.0, "Half-bath" -> 0.5
        # - "Bathroom" (no number) and missing -> missing
        # 1. the four texts from the spec
        @test P.parse_bathrooms("1 bath") == 1.0
        # P. is needed because the tests reach the package functions through P = Project1
        @test P.parse_bathrooms("1.5 shared baths") == 1.5
        @test P.parse_bathrooms("0 baths") == 0.0
        # zero is a real number, so the answer is 0.0 and not missing (remove_if_zero! deals with it later)
        @test P.parse_bathrooms("Half-bath") == 0.5
        # "half" has no number in the text, so the function returns 0.5

        # 2. text without a number and a missing value both give missing
        @test ismissing(P.parse_bathrooms("Bathroom"))
        # ismissing is used because missing == missing gives missing, not true, so @test could not judge it
        @test ismissing(P.parse_bathrooms(missing))

        # 3. the remaining branches: empty text, half with a prefix, capital letters
        @test ismissing(P.parse_bathrooms(""))
        # an empty text has no words, so the isempty(words) line returns missing
        @test P.parse_bathrooms("Shared half-bath") == 0.5
        # Airbnb writes it like this too, occursin finds "half" anywhere in the text
        @test P.parse_bathrooms("2 Baths") == 2.0
        # the capital B must not matter, because the text is lowercased first
    end
 
    @testset "impute_median_by_room_type!" begin
        # - a missing value gets the median of the same room type, not of all rows
        # - a room type without any known value is left untouched (no error)
        @test_broken false
    end
 
    @testset "process_missing!" begin
        # one small DataFrame per rule:
        # - :drop_row removes rows with missing
        # - :fill_zero replaces missing by 0
        # - :impute_median_by_room_type uses the median of the same room type
        # - :impute_median_or_drop_entire_home drops entire homes (P.CONFIG.entire_home_label),
        #   other room types get the median
        # - :fill_from_bathrooms_text fills from the text, rows without a number are removed,
        #   "0 baths" gives 0 and is NOT removed here
        # - rules are applied in order (:x => :fill_zero before :x => :drop_row keeps the row)
        # - an unknown rule throws an ErrorException
        @test_broken false
    end
 
    @testset "process_outliers!" begin
        # rules = (columns = [:price], method = :iqr, iqr_multiplier = 1.5, scale = :log, action = :drop_row)
        # - an extreme high price is removed, the normal prices stay
        # - an extreme low price is removed as well
        # - scale = :raw works
        # - errors: a value of 0 on the log scale, a missing value, an unknown method
        @test_broken false
    end
 
    @testset "format_dummies!" begin
        washer_rule = only(filter(r -> r.target == :has_washer, P.CONFIG.dummy_rules))
        pool_rule = only(filter(r -> r.target == :has_pool, P.CONFIG.dummy_rules))
        superhost_rule = only(filter(r -> r.target == :is_superhost, P.CONFIG.dummy_rules))
       
        df = DataFrame(amenities = ["[\"Washer\", \"Wifi\"]", "[\"Dishwasher\"]"])
        P.format_dummies!(df, washer_rule)
        @test df.has_washer == [1, 0]

        df = DataFrame(amenities = ["[\"Pool\"]", "[\"Pool table\"]"])
        P.format_dummies!(df, pool_rule)
        @test df.has_pool == [1, 0]
        @test eltype(df.has_pool) == Int

        df = DataFrame(is_superhost = ["t", "f"])
        P.format_dummies!(df, superhost_rule)
        @test df.is_superhost == [1, 0]
        @test eltype(df.is_superhost) == Int
        
        washer_delete_rule = merge(washer_rule, (delete = true,))
        df = DataFrame(id = [1, 2], amenities = ["[\"Washer\"]", "[\"Wifi\"]"])
        P.format_dummies!(df, washer_delete_rule)
        remaining_columns = names(df)
        @test "amenities" ∉ remaining_columns 
        @test df.has_washer == [1, 0]
        @test df.id == [1, 2]
        # - "Washer" -> 1, "Dishwasher" -> 0 for has_washer; "Pool" -> 1, "Pool table" -> 0 for has_pool
        # - the new column holds whole numbers (eltype Int)
        # - is_superhost "t"/"f" becomes 1/0 in the same column
        # - delete = true removes the source column
        #@test_broken false
    end
 
    @testset "calculate_ratio!" begin
        col_col_rule = only(filter(r -> r.target == :ratio_beds_bedrooms, P.CONFIG.ratio_rules))
        col_fixnum_rule = only(filter(r -> r.target == :occupancy_rate, P.CONFIG.ratio_rules))

        df = DataFrame(beds = [2, 3], bedrooms = [1, 2])
        P.calculate_ratio!(df, col_col_rule)
        @test df.ratio_beds_bedrooms == [2.0, 1.5]

        df = DataFrame(estimated_occupancy_l365d = [73, 146])
        P.calculate_ratio!(df, col_fixnum_rule)
        @test df.occupancy_rate == [0.2, 0.4]
        

        del_col_col_rule = merge(col_col_rule, (delete = true,))
        df = DataFrame(id = [1, 2], beds = [2, 3], bedrooms = [1, 2])
        P.calculate_ratio!(df, del_col_col_rule)
        remaining_columns = names(df)
        @test "beds" ∉ remaining_columns 
        @test "bedrooms" ∉ remaining_columns 
        @test df.ratio_beds_bedrooms == [2.0, 1.5]
        @test df.id == [1, 2]

        del_col_fixnum_rule = merge(col_fixnum_rule, (delete = true,))
        df = DataFrame(id = [1, 2], estimated_occupancy_l365d = [73, 146])
        P.calculate_ratio!(df, del_col_fixnum_rule)
        remaining_columns = names(df)
        @test "estimated_occupancy_l365d" ∉ remaining_columns  
        @test df.occupancy_rate == [0.2, 0.4]
        @test df.id == [1, 2]

        df = DataFrame(beds = [2, 3], bedrooms = [1, missing])
        @test_throws ErrorException P.calculate_ratio!(df, col_col_rule)

        df = DataFrame(beds = [2, 3], bedrooms = [1, 0])
        @test_throws ErrorException P.calculate_ratio!(df, col_col_rule)
        # - column / column and column / fixed number (365)
        # - delete = true removes the source columns
        # - a 0 or a missing value in the denominator throws an ErrorException
        #@test_broken false
    end
 
    @testset "calculate_distance!" begin
        # - a listing at the city center has distance 0
        # - one degree of latitude north of the center is about 111.19 km (atol = 0.05)
        # - delete = true removes latitude and longitude (if the team keeps this behaviour)
        @test_broken false
    end
 
    # ------------------------------------------------------------------------------------------
    # data_analysis.jl
    # ------------------------------------------------------------------------------------------
 
    @testset "split_dataset" begin
        # - 100 rows with 0.2 give 80 training and 20 test rows, no overlap, nothing lost
        # - both sets keep the original row order, the original DataFrame is unchanged
        # - 20 (percent) gives the same split as 0.2
        # - the same seed gives the same split, another seed a different one
        # - random_selection = false takes the last rows as test set
        # - 0, 1.0, 100, -5, 1000 and a split that leaves a set empty throw an ErrorException
        @test_broken false
    end
 
    @testset "regression_city / predict_apartment_performance / evaluate_regression" begin
        # - prices that follow an exact log-linear rule are predicted exactly (rtol = 1e-6),
        #   evaluate_regression gives r2 ≈ 1 and median_ae ≈ 0
        # - a model with log_scale = false works and has smearing == 1.0
        # - a log1p predictor works and the new DataFrame is not changed by the prediction
        # - errors: a missing value in a used column, a target of 0 with log_scale = true
        @test_broken false
    end
 
    # ------------------------------------------------------------------------------------------
    # pipeline.jl (these use the real data file, so they only pass once all functions work)
    # ------------------------------------------------------------------------------------------
 
    @testset "run_training_pipeline on the listings file" begin
        # - enough rows are left (the sandbox checks > 5000, which fits the Barcelona file;
        #   use a lower limit for a smaller city)
        # - every target and predictor of P.CONFIG.regression_models exists and has no missing value
        # - price and estimated_revenue are above 0
        # - no ratio denominator is 0 and every ratio is finite
        @test_broken false
    end
 
    @testset "run_analysis_pipeline" begin
        # - one fit and one score per entry of P.CONFIG.regression_models
        # - df_training and df_test together have as many rows as the input
        # - the price model reaches an R2 on the log scale above 0.5 on the test set
        @test_broken false
    end
 
    @testset "run_inference_pipeline" begin
        # fill in once its argument is decided:
        # - one valid apartment gives one row with every predictor of P.CONFIG.regression_models
        # - 0 bathrooms or bedrooms throws an error with a clear message
        @test_broken false
    end
 
end
 