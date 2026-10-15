"""
    Project1

HostWise: estimate a fair nightly price and the yearly revenue of an apartment from the Inside Airbnb listings
of a city. Start the program with `julia src/main.jl`.
"""
module Project1

# Files to be included
include("config.jl")
include("data_import.jl")
include("data_pre_processing.jl")
include("data_analysis.jl")
include("user_interface.jl")
include("visualization.jl")
include("pipeline.jl")

# Functions to be exported
# Functions to be exported
export run_training_pipeline, run_inference_pipeline, run_analysis_pipeline, predict_apartment_performance, evaluate_regression, regression_city, prepare_predictors, split_dataset,
       import_csv, filter_columns, format_labels!, set_types!, convert_currency!, remove_duplicates!, remove_if_zero!, process_missing!, process_outliers!,
       format_dummies!, calculate_ratio!, calculate_distance!, gui

end # module Project1
