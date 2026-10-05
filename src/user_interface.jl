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
    ask_multiple() -> Set{Int}

User interface in REPL allowing a user to select multiple options from a menu.

# Arguments
- `title::String`:          Title of the menu.
- options::AbstractVector:  Menu items.


Returns `indices` Set{Int} with the users choices (empty if user cancels input).
"""
function ask_multiple(title::String, options::AbstractVector; io_in::IO = stdin, io_out::IO = stdout)
    # Multi-select menu
    MultiSelectMenu(options; pagesize=-1, selected=Int[], charset=:unicode)
end