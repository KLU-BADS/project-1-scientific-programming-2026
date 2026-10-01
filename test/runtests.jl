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
 
    @testset "filter_columns / format_labels!" begin
        # - only the listed columns are left
        # - the original DataFrame still has all its columns (filter_columns returns a copy)
        # - format_labels! renames the columns in the Dict in place and leaves the others alone
        @test_broken false
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
        @test_broken false
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
        # use the real rules: only(filter(r -> r.target == :has_washer, P.CONFIG.dummy_rules))
        # - "Washer" -> 1, "Dishwasher" -> 0 for has_washer; "Pool" -> 1, "Pool table" -> 0 for has_pool
        # - the new column holds whole numbers (eltype Int)
        # - is_superhost "t"/"f" becomes 1/0 in the same column
        # - delete = true removes the source column
        @test_broken false
    end
 
    @testset "calculate_ratio!" begin
        # - column / column and column / fixed number (365)
        # - delete = true removes the source columns
        # - a 0 or a missing value in the denominator throws an ErrorException
        @test_broken false
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
        # standard call with random permutation: create test data set then split into training and test sets with random permutation
        df = DataFrame(a = 1:100, b = 101:200)
        df_rand = P.split_dataset(df, 0.2; random_selection = true, seed = 42)
        # 100 rows with 0.2 give 80 training and 20 test rows, no overlap, nothing lost
        @test nrow(df_rand[1]) == 0.8 * 100
        @test nrow(df_rand[2]) == 0.2 * 100
        @test isempty(intersect(df_rand[1].a, df_rand[2].a))
        @test length(union(df_rand[1].a, df_rand[2].a)) == 100
        
        # original unchanged: original DataFrame df remains unchanged
        @test df == DataFrame(a = 1:100, b = 101:200)

        # random_selection = false: create test data set, then split into training and test sets without random permutation
        df_ordered = P.split_dataset(df, 0.2; random_selection = false)
        # return values are in order
        @test df_ordered[1].a == 1:80
        @test df_ordered[1].b == 101:180
        @test df_ordered[2].a == 81:100
        @test df_ordered[2].b == 181:200       
        
        # - the same seed gives the same split, another seed a different one
        df_same_seed = P.split_dataset(df, 0.2; random_selection = true, seed = 42)
        df_new_seed = P.split_dataset(df, 0.2; random_selection = true, seed = 87)
        @test df_same_seed == df_rand
        @test df_same_seed != df_new_seed   

        # percentage split: percentage value returns the same as decimal value
        df_percent = P.split_dataset(df, 20; random_selection = true, seed = 42)
        @test df_rand == df_percent

        # error handling: values - 0, 1.0, 100, -5, 1000 and a split that leaves a set empty throw an ErrorException
        @test_throws ArgumentError P.split_dataset(df, 0; random_selection = true, seed = 42)
        @test_throws ArgumentError P.split_dataset(df, 1.0; random_selection = true, seed = 42)
        @test_throws ArgumentError P.split_dataset(df, -5; random_selection = true, seed = 42)
        @test_throws ArgumentError P.split_dataset(df, 100; random_selection = true, seed = 42)
        @test_throws ArgumentError P.split_dataset(df, 1000; random_selection = true, seed = 42)
        @test_throws ArgumentError P.split_dataset(df, 0.00001; random_selection = true, seed = 42)
        @test_throws ArgumentError P.split_dataset(df, 0.99999; random_selection = true, seed = 42)
    end
 
    @testset "prepare_predictors" begin
        # create the data frame
        df = DataFrame(
            fixed = 1:5,
            variable = [1, 0, 22.5, 10000, ℯ - 1]
        )

        # create specs
        specs = (log1p_predictors = Symbol[:variable],)

        # call function with test data
        df_log1p = P.prepare_predictors(df, specs)

        # correct values?
        @test df_log1p.variable ≈ [log1p(1),log1p(0),log1p(22.5),log1p(10000),log1p(ℯ - 1)]
        
        # non-specified columns unchanged?
        @test df_log1p.fixed ≈ 1:5
        
        # input DataFrame remains unchanged?
        @test df == DataFrame(
            fixed = 1:5,
            variable = [1, 0, 22.5, 10000, ℯ - 1]
        )

        # input consistent: same output for input with the same values
        df_2 = DataFrame(
            fixed = 1:5,
            variable = [1, 0, 22.5, 10000, ℯ - 1]
        )
        @test isequal(P.prepare_predictors(df, specs), P.prepare_predictors(df_2, specs))

        # column names unchanged?
        @test names(df_log1p) == names(df)

        # dimensions indetical?
        @test nrow(df_log1p) == nrow(df)
        @test ncol(df_log1p) == ncol(df)

        # returns copy?
        @test P.prepare_predictors(df, specs) !== df

        # no columns in specs: returns a copy of the same data frame
        specs_no_reference = (log1p_predictors = Symbol[],)
        @test P.prepare_predictors(df, specs_no_reference) isa DataFrame
        @test P.prepare_predictors(df, specs_no_reference) == DataFrame(
            fixed = 1:5,
            variable = [1, 0, 22.5, 10000, ℯ - 1]
        )

        # error handling: missing values, negative values should throw error
        df_error_missing = DataFrame(
            fixed = 1:5,
            variable = [1, missing , 22.5, 10000, ℯ - 1]
        )
        @test_throws ArgumentError P.prepare_predictors(df_error_missing, specs)
        df_error_negative = DataFrame(
            fixed = 1:5,
            variable = [1, -2, 22.5, 10000, ℯ - 1]
        )
        @test_throws DomainError P.prepare_predictors(df_error_negative, specs)

        #@test_broken false
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
 