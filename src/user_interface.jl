"""
    ask_yes_no(prompt; io_in = stdin, io_out = stdout) -> Union{Bool, Nothing}

User interface in the REPL asking a yes/no question. Repeats the question until a valid answer is given.

# Arguments
- `prompt::AbstractString`:   Question shown to the user.
- `io_in::IO`:                Input stream (default `stdin`); pass an `IOBuffer` in tests.
- `io_out::IO`:               Output stream for the prompt and messages (default `stdout`).

Returns `true` for y/yes/t/true and `false` for n/no/f/false (not case-sensitive), or `nothing` if the user
enters `q`, `quit` or `exit` or the input ends before a valid answer is given.
"""
function ask_yes_no(prompt::AbstractString; io_in::IO = stdin, io_out::IO = stdout)
    yes_values = ("y", "yes", "t", "true")
    no_values = ("n", "no", "f", "false")
    # start with a value that is not accepted, so the loop runs at least once
    answer = ""
    while !(answer in yes_values || answer in no_values)
        # show a hint after an invalid answer (not before the first one)
        answer == "" || println(io_out, "Please answer y or n.")
        # write prompt to terminal
        print(io_out, prompt)
        # ensure prompt appears before the program waits for input
        flush(io_out)
        # stop instead of looping forever if the input has ended
        eof(io_in) && return nothing
        # read line and normalize it (remove spaces/newline, lowercase)
        answer = lowercase(strip(readline(io_in)))
        answer in ("q", "quit", "exit") && return nothing
    end
    # true for a yes-value, false for a no-value
    return answer in yes_values
end