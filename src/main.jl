# Activate and install this project's environment, so the script runs from any launcher
# (terminal, VS Code, REPL) and for every teammate without extra steps.
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using Project1


"""
    main()

Excecute the program.

Returns `nothing`.

<!-- TODO: add an `# Examples` section with a jldoctest once this function is implemented. -->
"""
function main()
    #df_processed = run_training_pipeline()
    #analysis = run_analysis_pipeline(df_processed)
end


main()