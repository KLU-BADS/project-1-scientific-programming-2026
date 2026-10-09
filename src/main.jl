# Activate and install this project's environment, so the script runs from any launcher
# (terminal, VS Code, REPL) and for every teammate without extra steps.
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using Project1


"""
    main()

Run the HostWise program: prepare the data, fit the models and open the menu in the terminal.

1. The user chooses the city among the cities with a listings file in `data/raw` (`available_cities`);
   with only one city there is no question, and Exit ends the program.
2. `run_training_pipeline(data_filepath(city); city = city)` imports and prepares the listings of that city
   and keeps the values learned from them (`fitted`: caps, kept districts, square centres, city).
3. `run_analysis_pipeline(df)` splits the data into a training and a test set and fits and scores the models.
4. `gui(...)` opens the main menu with the analysis and `fitted`; the program ends when the user chooses "Exit".

Start it from a terminal with `julia src/main.jl`: the menus need a real terminal.

Returns `nothing`.
"""
function main()
    # 1. the cities with a listings file in data/raw; only these can be offered
    cities = Project1.available_cities(Project1.CONFIG.cities, joinpath(Project1.PROJECT_ROOT, "data", "raw"))
    # Project1. is needed because these functions are not exported

    # 2. choose the city: a menu if there are several, no question if there is only one
    city = length(cities) == 1 ? only(cities) : Project1.ask_choice("Which city?", [c => c for c in cities])
    # [c => c for c in cities] gives label => value pairs, e.g. "Athens" => "Athens", as ask_choice expects
    isnothing(city) && return nothing
    # Exit (or q) in the city menu ends the program before anything is loaded

    # 3. prepare the data of the chosen city, fit the models and open the menu
    println("Loading and preparing the data of $city …")
    (df_processed, fitted) = run_training_pipeline(Project1.data_filepath(city); city = city)
    println("Running analysis …")
    analysis = run_analysis_pipeline(df_processed)
    println("Initializing user interface …")
    gui(merge(analysis, (fitted = fitted,)))
    return nothing
end


main()