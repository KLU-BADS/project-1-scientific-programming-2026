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