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
    ask_number() -> Type{<:Real}

User interface in REPL allowing a user to enter a number and returns the number in the correct type.

# Arguments
- `prompt::String`:     Prompt to user.
- `T::Type{<:Real}`:    Input data type for parsing.
- `min<:Real`:          Lower boundary of input interval.
- `max<:Real`:          Upper boundary of input interval.
- `inclusive_interval`::Bool = false: If true then min and max are smaller/greater THAN, if false smaller/greater


Returns `number` of type `T` with the users choices (empty if user cancels input).
"""
function ask_number(prompt::String, T::Type{<:Real}, min::Real, max::Real, inclusive_interval::Bool = false; io_in::IO = stdin, io_out::IO = stdout)
    valid = false
    num::Real
    while !valid
        # write prompt to terminal
        print(io_out, prompt)
        # ensure prompt appears before program waits for input
        flush(io_out)
        # Read line
        eof(io_in) && return nothing
        s = strip(readline(io_in))
        # remove white spaces
        s = strip(s)
        # Parse number
        num = tryparse(T,s)
        # check validity of input
        isnothing(num) && (print("Not a valid input!"; continue))
        # Check range (maybe implement ranges in CONFIG?!)
        valid = inclusive_interval ? (min <= num <= max) : (min < num < max)
    end
    return num
end

"""
    ask_yes_no() -> Type{<:Real}

User interface in REPL allowing a select yes/no

# Arguments
- `prompt::String`:   Question shown to the user.
- `io_in::IO`:        Input stream (default `stdin`); pass an `IOBuffer` in tests.
- `io_out::IO`:       Output stream for the prompt (default `stdout`).

# Throws
- `EOFError` if the input ends before a valid answer is given.

Returns `true` for y/yes/t/true and `false` for n/no/f/false (case-insensitive).
"""
function ask_yes_no(prompt::String; io_in::IO = stdin, io_out::IO = stdout)
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
        eof(io_in) && throw(EOFError())
        # read line and normalize it (remove spaces/newline, lowercase)
        answer = lowercase(strip(readline(io_in)))
    end
    # true for a yes-value, false for a no-value
    return answer in yes_values
end