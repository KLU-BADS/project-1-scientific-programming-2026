using REPL.TerminalMenus

"""
    gui()

User interface in REPL allowing a user to view analysis results and enter information about his apartment

# Arguments
- `config.Promts::NamedTuple`:  promts for the menu

Returns 
"""
function gui()

end

"""
    ask_choice() -> Int

User interface in REPL allowing a user to select a single choice from a menu.

# Arguments
- `title::String`:          title of the menu.
- options::Vector{String}:  menu items.


Returns `index` with the users choice or -1 if user cancels input.
"""
function ask_choice(title::String, options::Vector{String}; io_in::IO = stdin, io_out::IO = stdout)
    # Radio Menu
    RadioMenu(options; pagesize=-1, charset=:unicode, keybindings=Char[])
end


"""
    ask_number(prompt, T, min_value = -Inf, max_value = Inf, inclusive_interval = false; io_in = stdin, io_out = stdout) -> Union{T, Nothing}

User interface in the REPL allowing a user to enter a number. Repeats the question until a valid number in the
permitted range is entered.

# Arguments
- `prompt::AbstractString`:     Prompt shown to the user.
- `T::Type{<:Real}`:            Type the input is parsed to, e.g. `Int` or `Float64`.
- `min_val::Real`:              Lower boundary of the allowed interval (default `-Inf`, no lower boundary).
- `max_val::Real`:              Upper boundary of the allowed interval (default `Inf`, no upper boundary).
- `inclusive_interval::Bool`:   If `true`, `min_val` and `max_val` themselves are allowed (`min_val <= x <= max_val`);
                                if `false` (default), they are not (`min_val < x < max_val`).
- `io_in::IO`:                  Input stream (default `stdin`); pass an `IOBuffer` in tests.
- `io_out::IO`:                 Output stream for the prompt and messages (default `stdout`).

Returns the entered number as type `T`, or `nothing` if the user enters `q`, `quit` or `exit`
(not case-sensitive) or the input ends before a valid number is given.

# Examples

```jldoctest
julia> Project1.ask_number("Guests: ", Int, 1, 16, true; io_in = IOBuffer("4\\n"), io_out = IOBuffer())
4

julia> Project1.ask_number("Guests: ", Int, 1, 16, true; io_in = IOBuffer("q\\n"), io_out = IOBuffer()) === nothing
true
```
"""
function ask_number(prompt::AbstractString, T::Type{<:Real}, min_value::Real = -Inf, max_value::Real = Inf, inclusive_interval::Bool = false; io_in::IO = stdin, io_out::IO = stdout)
    while true
        # write prompt to terminal
        print(io_out, prompt)
        # ensure prompt appears before program waits for input
        flush(io_out)
        # stop if the input has ended
        eof(io_in) && return nothing
        # read line, remove white spaces and parse number
        input = strip(readline(io_in))
        lowercase(input) in ("q", "quit", "exit") && return nothing
        value = tryparse(T, input)
        # not a number: ask again
        if isnothing(value)
            if T <: Integer
                println(io_out, "Not a valid input, enter a whole number!")
            else
                println(io_out, "Not a valid input, enter a number!")
            end
            continue
        end
        # check range
        in_range = inclusive_interval ? (value >= min_value && value <= max_value) : (value > min_value && value < max_value)
        in_range && return value
        println(io_out, "Please enter a number between $(min_value) and $(max_value).")
    end
end
