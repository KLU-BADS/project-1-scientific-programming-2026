using REPL.TerminalMenus

"""
    gui(analysis; io_in = stdin, io_out = stdout)

Run the terminal menu of the program until the user chooses Exit: show the market findings,
price a new apartment or check a listed one.

# Arguments
- `analysis::NamedTuple`:   The result of `run_analysis_pipeline` together with `fitted` from `run_training_pipeline`.
- `io_in::IO`:              Where the typed answers are read from (default `stdin`, the keyboard).
- `io_out::IO`:             Where the screens are printed (default `stdout`, the terminal).

# Throws
- Every error except an `ArgumentError` from the input is passed on unchanged.

Returns `nothing` once the user chooses Exit.

# Examples
No example here: the menus need a real keyboard, so gui is tested by hand in the terminal.
"""
function gui(analysis::NamedTuple; io_in::IO = stdin, io_out::IO = stdout)
    # the group importance fits the price model once per group, so it is computed on the first visit only
    importance = nothing
    # nothing means "not computed yet"; the findings screen fills it in the first time it is opened

    # the menu repeats until the user chooses Exit, which ends the function with return
    while true
        # 1. the main menu; ask_choice adds Exit itself and gives back nothing for it
        choice = ask_choice("What would you like to do?", ["Market findings" => :findings, "Price a new apartment" => :new, "Check my listed apartment" => :listed, "Change city" => :change_city])
        # every option is a pair "label" => value: the user sees the label, the program gets the Symbol
        isnothing(choice) && return nothing
        # a && b only runs b when a is true, so Exit (or q) leaves the loop and the whole function
        choice == :change_city && return :change_city
        # main shows the city menu again when gui gives back :change_city

        # 2. the market findings, with the importance table computed once and reused on every later visit
        if choice == :findings
            if isnothing(importance)
                fit = get_fit(analysis.fits, :price)
                # the importance is measured on the price model, the one the users see their price from
                importance = group_importance(analysis.df_training, analysis.df_test, fit.spec, CONFIG.importance_groups; reference_levels = CONFIG.reference_levels)
            end
            visualize_general_findings(analysis; io = io_out, importance = importance)
        else
            # 3. a new or a listed apartment: ask for its data, predict, and show the result screen
            answers = enter_apartment_data(choice, analysis.df_training; center = CONFIG.cities[analysis.fitted.city].center, io_in = io_in, io_out = io_out)
            # choice is :new or :listed, so the questions match the group (a listed apartment also gets its price and nights)
            if isnothing(answers)
                println(io_out, "Cancelled.")
            else
                try
                    df = run_inference_pipeline(import_user_input(answers), analysis.fitted)
                    # the answers become a one-row table and get the same preparation as the training data
                    result = run_prediction_pipeline(analysis, df, choice)
                    # the price range, revenue, assessment and tips of this one apartment
                    visualize_results(result; io = io_out)
                catch exception
                    # a wrong answer stops only this prediction; any other error is a bug, so it stops the program
                    exception isa ArgumentError || rethrow()
                    # a || b only runs b when a is false; rethrow() passes the same error on unchanged
                    println(io_out, "Could not predict this apartment: ", exception.msg)
                    # .msg is the sentence the ArgumentError was created with, e.g. "group must be :new or :listed"
                end
            end
            # enter_apartment_data gives back nothing when the user leaves a question, so nothing is predicted
        end

        # 4. wait, so the screen stays visible until the user has read it
        println(io_out, "Press Enter to return to the menu.")
        readline(io_in)
        # readline waits for one line of input; what the user types is not needed, so it is not stored
    end
end


"""
    enter_apartment_data(group, df_training; center = CONFIG.cities[CONFIG.city].center, io_in = stdin, io_out = stdout) -> Dict{Symbol,Any} or nothing

Ask the user every question about one apartment and collect the answers under their final column names,
so they can be turned into a one-row table for the model. The questions, in this order:

1. room type (menu, only room types with enough training listings);
2. size questions (guests, bedrooms, beds, bathrooms, minimum nights), limited by the room type;
3. location (latitude and longitude), from which the district is derived;
4. amenities (multiple choice), stored as 0/1 columns;
5. Superhost (yes/no), stored as 0/1;
6. listed apartments only: current price, average rating and booked nights.
   New apartments get the median training rating instead, without a question.

# Arguments
- `group::Symbol`:              `:new` for an apartment that is not listed yet, `:listed` for a listed one.
- `df_training::DataFrame`:     training data, used for the menu options and the limits of every question.
- `center::NamedTuple`:         centre of the chosen city (default the config city), used for the location check.
- `io_in::IO`:                  input stream for the typed questions (default `stdin`).
- `io_out::IO`:                 output stream for the prompts and messages (default `stdout`).

The two menus always use the terminal, so this function is tested by hand; its parts are tested on their own.

# Throws
- `ArgumentError`   if `group` is not `:new` or `:listed`.

Returns a `Dict{Symbol,Any}` with the answers, or `nothing` as soon as the user leaves at any question.
For listed apartments it also contains `:price` and `:estimated_occupancy_l365d`; the price is compared
with the predicted range and is not a predictor.
"""
function enter_apartment_data(group::Symbol, df_training::DataFrame; center::NamedTuple = CONFIG.cities[CONFIG.city].center, io_in::IO = stdin, io_out::IO = stdout)
    # throw exception if group name is wrong
    group in (:new, :listed) || throw(ArgumentError("group must be :new or :listed"))
    
    # empty dictionary to collect the user responses
    answers = Dict{Symbol,Any}()
   
    # decide which type of rooms to offer based on sufficient observations of this room type in training set
    room_type_options = get_room_type_options(df_training, CONFIG.min_room_type_count)
    # get user input
    room_type_input = ask_choice("Room type", room_type_options)
    isnothing(room_type_input) && return nothing
    answers[:room_type] = room_type_input
    
    # get the size rules valid for both groups
    size_rules = filter(rule -> :new in rule.groups, CONFIG.input_rules)
    # get number user inputs in order specified in size_rules
    ask_numbers!(answers, size_rules, df_training, CONFIG.plausibility_rules; io_in = io_in, io_out = io_out) || return nothing
    
    # get location of apartment and derive district
    location_input = ask_location(df_training, CONFIG.distance_rule, CONFIG.location_rule, center; io_in = io_in, io_out = io_out)
    isnothing(location_input) && return nothing
    answers[:latitude] = location_input.latitude
    answers[:longitude] = location_input.longitude
    answers[:district] = derive_district(location_input.latitude, location_input.longitude, df_training, CONFIG.distance_rule)

    # let the user select available amenities
    amenity_columns = get_amenity_columns(CONFIG.dummy_rules)
    amenities_selection = ask_multiple("Amenities (Enter = select, d = done)", [CONFIG.amenity_labels[amenity] => amenity for amenity in amenity_columns])
    merge!(answers, selection_to_dummies(amenities_selection, amenity_columns))

    # get users superhost status
    superhost_input = ask_yes_no("Are you already a Superhost (also from other listings)? "; io_in = io_in, io_out = io_out)
    isnothing(superhost_input) && return nothing
    answers[:is_superhost] = Int(superhost_input)

    # get ratings scores
    if group == :new
        # median inserted for new apartments without review --> neutral
        answers[:review_scores_rating] = median(df_training.review_scores_rating)
    else
        listed_rules = filter(r -> !(:new in r.groups), CONFIG.input_rules)
        ask_numbers!(answers, listed_rules, df_training, CONFIG.plausibility_rules; io_in = io_in, io_out = io_out) || return nothing
    end
    return answers
end

"""
    get_room_type_options(df_training, min_room_type_count) -> Vector{Pair{String,String}}

Return the room types to offer in the room type menu, as `label => value` pairs for `ask_choice`.
Only room types with at least `min_room_type_count` training listings are offered, because rarer ones
give no reliable price limits or prediction.

# Arguments
- `df_training::DataFrame`:         training data with the column `room_type`.
- `min_room_type_count::Integer`:   smallest number of listings a room type needs, e.g. `CONFIG.min_room_type_count`.

# Throws
- `MethodError`   if `min_room_type_count` is not a whole number, e.g. `2.5`.

Returns the pairs sorted alphabetically; label and value are the same text, exactly as in the data
(e.g. `"Entire home/apt" => "Entire home/apt"`). The text is always a plain `String`, also when CSV
read the column with a compact text type such as `String15`. Returns an empty list if no room type
has enough listings.

# Examples
```jldoctest
julia> df = DataFrame(room_type = ["Private room", "Entire home/apt", "Entire home/apt", "Hotel room"]);

julia> Project1.get_room_type_options(df, 2)
1-element Vector{Pair{String, String}}:
 "Entire home/apt" => "Entire home/apt"
```
"""
function get_room_type_options(df_training::DataFrame, min_room_type_count::Integer)
    counts = combine(groupby(df_training, :room_type), nrow => :n) 
    filter_room_types = filter(row -> row.n >= min_room_type_count, counts)
    room_types = sort(filter_room_types.room_type)
    return [String(rt) => String(rt) for rt in room_types]
end

"""
    ask_choice(title, options) -> value or nothing

Show a menu in the terminal and let the user pick one item. An "Exit" item is always
added as the last item, so callers do not include it themselves.

# Arguments
- `title::AbstractString`:              question shown above the menu.
- `options::AbstractVector{<:Pair}`:    menu items as `label => value` pairs,
                                        e.g. `["Price a new apartment" => :new, "Check my listed apartment" => :listed]`.

# Throws
- `ArgumentError`   if `options` is empty or a label is not a text.
- `MethodError`     if `options` is not a list of pairs, e.g. plain texts.

Returns the value of the chosen pair, or `nothing` if the user chooses "Exit",
presses `q` or presses Ctrl-C. Callers check the result with `isnothing`.

# Examples
```jldoctest
julia> Project1.ask_choice("Menu", Pair{String,Symbol}[])
ERROR: ArgumentError: options must not be empty

julia> Project1.ask_choice("Menu", [1 => :new, 2 => :listed])
ERROR: ArgumentError: every option must be a pair label => value with a text label
```
"""
function ask_choice(title::AbstractString, options::AbstractVector{<:Pair})
    # catch empty options vector
    isempty(options) && throw(ArgumentError("options must not be empty"))
    # check wrong structure of options vector
    all(p -> first(p) isa AbstractString, options) || throw(ArgumentError("every option must be a pair label => value with a text label"))
    # set labels for RadioMenu options (first add exit option to input options)
    all_options = vcat(options, ["Exit" => nothing])
    labels = String.(first.(all_options))
    # get user input from RadioMenu
    menu = RadioMenu(labels; pagesize = min(15, length(labels)), charset = :unicode, ctrl_c_interrupt = false)
    user_selection = request(title, menu)
    # return nothing if user left the menu or selected exit option, otherwise return value
    return user_selection == -1 ? nothing : last(all_options[user_selection])
end

"""
    ask_multiple(title, options) -> Vector

Show a menu in the terminal in which the user can tick several items.
Enter ticks or unticks an item, `d` finishes, `q` cancels.

# Arguments
- `title::AbstractString`:              question shown above the menu; mention that `d` finishes,
                                        e.g. "Amenities (Enter = select, d = done)".
- `options::AbstractVector{<:Pair}`:    menu items as `label => value` pairs,
                                        e.g. `["Air conditioning" => :has_AC, "TV" => :has_tv]`.

# Throws
- `ArgumentError`   if `options` is empty or a label is not a text.
- `MethodError`     if `options` is not a list of pairs, e.g. plain texts.

Returns the values of all ticked items in menu order, e.g. `[:has_AC, :has_tv]`.
Returns an empty list if nothing was ticked or the user pressed `q`.

# Examples
```jldoctest
julia> Project1.ask_multiple("Amenities", Pair{String,Symbol}[])
ERROR: ArgumentError: options must not be empty

julia> Project1.ask_multiple("Amenities", [1 => :has_AC, 2 => :has_tv])
ERROR: ArgumentError: every option must be a pair label => value with a text label
```
"""
function ask_multiple(title::AbstractString, options::AbstractVector{<:Pair})
    # catch empty options vector
    isempty(options) && throw(ArgumentError("options must not be empty"))
    # check wrong structure of options vector
    all(p -> first(p) isa AbstractString, options) || throw(ArgumentError("every option must be a pair label => value with a text label"))
    # set labels for MultiSelectMenu options (first add exit option to input options)
    labels = String.(first.(options))
    # get user input from MultiSelectMenu and sort it
    menu = MultiSelectMenu(labels; charset = :unicode, ctrl_c_interrupt = false)
    user_selection = request(title, menu)
    sorted_user_selection = sort(collect(user_selection))
    # return all selected menu items
    return [last(options[i]) for i in sorted_user_selection]
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

"""
    ask_location(df_training, distance_rule, location_rule, center; io_in = stdin, io_out = stdout) -> NamedTuple or nothing

Ask the user for the latitude and longitude of the apartment. Only locations inside the area covered by the
training data are accepted: each coordinate must lie between the training extremes (widened by a small margin),
and the distance to the city center must not exceed the largest training distance (plus a small margin).
Asks again until a valid location is entered.

# Arguments
- `df_training::DataFrame`:     training data with the columns `latitude`, `longitude` and `proximity_city_center`
                                (so `calculate_distance!` must have run with `delete = false`).
- `distance_rule::NamedTuple`:  the distance rule from the config, e.g. `CONFIG.distance_rule`.
- `location_rule::NamedTuple`:  margins from the config, `(coordinate_margin_deg = …, distance_margin_km = …)`.
- `center::NamedTuple`:         city center as `(latitude = …, longitude = …)`.
- `io_in::IO`:                  input stream (default `stdin`); pass an `IOBuffer` in tests.
- `io_out::IO`:                 output stream for the prompts and messages (default `stdout`).

# Throws
- `ArgumentError`   if `df_training` has no column `latitude`, `longitude` or `proximity_city_center`.

Returns `(latitude = …, longitude = …)`, or `nothing` if the user enters `q`, `quit` or `exit`
at either question or the input ends.

# Examples
```jldoctest
julia> df = DataFrame(latitude = [37.96, 38.00, 37.98], longitude = [23.71, 23.75, 23.73],
                      proximity_city_center = [2.5, 2.5, 0.0]);

julia> rule = (target = :proximity_city_center, source_columns = (latitude = :latitude, longitude = :longitude), delete = false);

julia> Project1.ask_location(df, rule, (coordinate_margin_deg = 0.0, distance_margin_km = 0.0), (latitude = 37.98, longitude = 23.73);
                             io_in = IOBuffer("37.99\\n23.73\\n"), io_out = IOBuffer())
(latitude = 37.99, longitude = 23.73)
```
"""
function ask_location(df_training::DataFrame, distance_rule::NamedTuple, location_rule::NamedTuple, center::NamedTuple; io_in::IO = stdin, io_out::IO = stdout)
    # get min/max values for latitude/longitude input from the training data and expand by a small margin
    latitude_min, latitude_max = extrema(df_training.latitude) .+ (-location_rule.coordinate_margin_deg, location_rule.coordinate_margin_deg)
    longitude_min, longitude_max = extrema(df_training.longitude) .+ (-location_rule.coordinate_margin_deg, location_rule.coordinate_margin_deg)
    # set maximum distance from city center based on the training data plus a small margin
    distance_max = maximum(df_training.proximity_city_center) + location_rule.distance_margin_km
    # get user input with min/max the extrema from the training data plus a small margin, if user exits return nothing
    while true
        latitude_input = ask_number("Latitude (e.g. $(round(center.latitude; digits = 3))): ", Float64, latitude_min, latitude_max, true; io_in = io_in, io_out = io_out)
        isnothing(latitude_input) && return nothing
        longitude_input = ask_number("Longitude (e.g. $(round(center.longitude; digits = 3))): ", Float64, longitude_min, longitude_max, true; io_in = io_in, io_out = io_out)
        isnothing(longitude_input) && return nothing
        # calculate distance to city center and verify validity of the input
        location = DataFrame(latitude = [latitude_input], longitude = [longitude_input])
        calculate_distance!(location, merge(distance_rule, (target = :d, delete = false)), center)
        if location.d[1] > distance_max
            println(io_out, "This location is outside the area our data covers.")
            continue
        end
        # return values
        return (latitude = latitude_input, longitude = longitude_input)
    end
end

"""
    ask_numbers!(answers, rules, df_training, plausibility_rules; io_in = stdin, io_out = stdout) -> Bool

Ask the numeric questions about the apartment one after another and store each answer in `answers`.
The limits of every question come from `input_bounds`: the fixed limits of the rule or, if they are `nothing`,
the range of the training data for the chosen room type, tightened by the plausibility rules
(e.g. the number of bathrooms depends on the number of bedrooms entered before).

# Arguments
- `answers::AbstractDict{Symbol,Any}`:                  answers so far; must already contain `:room_type`.
                                                        Changed in place: each answer is stored under its column name.
- `rules::AbstractVector{<:NamedTuple}`:                the questions in the order they are asked, e.g. the entries of
                                                        `CONFIG.input_rules` for one group. Each rule has the fields
                                                        `column`, `value_type`, `min`, `max` and `prompt`.
- `df_training::DataFrame`:                             training data, used for the limits of the room type.
- `plausibility_rules::AbstractVector{<:NamedTuple}`:   e.g. `CONFIG.plausibility_rules`; limits that depend on earlier answers.
- `io_in::IO`:                                          input stream (default `stdin`); pass an `IOBuffer` in tests.
- `io_out::IO`:                                         output stream for the prompts and messages (default `stdout`).

Returns `true` when every question was answered, or `false` as soon as the user enters `q`, `quit` or `exit`
or the input ends. The answers given until then stay in `answers`.

The order of `rules` matters: a question whose limits depend on another answer (bathrooms on bedrooms)
must come after it.
"""
function ask_numbers!(answers::AbstractDict{Symbol,Any}, rules::AbstractVector{<:NamedTuple}, df_training::DataFrame, plausibility_rules::AbstractVector{<:NamedTuple}; io_in::IO = stdin, io_out::IO = stdout)
    # for each number input governed by an interval get the boundaries and then get the user input, if the input is correct add the user response to answers Dict
    for rule in rules
        (lower_bound, upper_bound) = input_bounds(rule, answers, df_training, plausibility_rules)
        value = ask_number(rule.prompt, rule.value_type, lower_bound, upper_bound, true; io_in = io_in, io_out = io_out)
        isnothing(value) && return false
        answers[rule.column] = value
    end
    return true
end