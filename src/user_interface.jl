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
        isnothing(num) && (println(io_out, "Not a valid input!"); continue)
        # Check range (maybe implement ranges in CONFIG?!)
        valid = inclusive_interval ? (min <= num <= max) : (min < num < max)
    end
    return num
end