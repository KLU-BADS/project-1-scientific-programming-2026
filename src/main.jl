# Activate and install this project's environment, so the script runs from any launcher
# (terminal, VS Code, REPL) and for every teammate without extra steps.
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using Project1


"""
    main()

Run the HostWise program: prepare the data, fit the models and open the menu in the terminal.

1. `run_training_pipeline()` imports and prepares the listings of `CONFIG.city` and keeps the values
   learned from them (`fitted`: caps, kept districts, square centres).
2. `run_analysis_pipeline(df)` splits the data into a training and a test set and fits and scores the models.
3. `gui(...)` opens the main menu with the analysis and `fitted`; the program ends when the user chooses "Exit".

Start it from a terminal with `julia src/main.jl`: the menus need a real terminal.

Returns `nothing`.
"""
function main()
    println("Loading and preparing the data …")
    (df_processed, fitted) = run_training_pipeline()
    println("Running analysis …")
    analysis = run_analysis_pipeline(df_processed)
    println("Initializing user interface …")
    gui(merge(analysis, (fitted = fitted,)))
    return nothing
end


main()