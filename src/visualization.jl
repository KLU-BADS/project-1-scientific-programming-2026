using DataFrames, Printf, UnicodePlots

"""
    format_eur(x; digits = 0)

Format a number as a euro amount with a comma between every three digits, for example `7272` becomes `"€7,272"`.

# Arguments
- `x`:          The amount to format.
- `digits`:     Number of decimal places to keep (default 0).

Returns the amount as a `String` that starts with `€`.

# Examples
```jldoctest
julia> Project1.format_eur(7272)
"€7,272"

julia> Project1.format_eur(7.5; digits = 2)
"€7.50"
```
"""
function format_eur(x::Real; digits::Int = 0)
    # 1. round x to the wanted number of decimals and turn it into text
    s = @sprintf("%.*f", digits, x)
    # %.*f = a number with decimals, the * takes how many decimals from digits
    # @sprintf("%.*f", 0, 7272.4) = "7272" and @sprintf("%.*f", 2, 7.5) = "7.50"

    # 2. split the text into the whole part and the decimals
    parts = split(s, ".")
    whole = parts[1]
    # split("7.50", ".") = ["7", "50"], and split("7272", ".") = ["7272"] when there are no decimals

    # 3. put a comma before every group of three digits, counted from the right
    whole = replace(whole, r"(?<=\d)(?=(\d{3})+$)" => ",")
    # the pattern finds every place with a digit before it and a multiple of three digits after it
    # "1234567" has two such places, so it becomes "1,234,567"

    # 4. join the decimals back if there are any and put the euro sign in front
    if length(parts) == 2
        return "€" * whole * "." * parts[2]
    end
    return "€" * whole
end

"""
    range_bar(lower, upper, value; width = 30, current = nothing)

Draw the price range from `lower` to `upper` as a text bar with a `●` at the predicted price `value`.
If the current price `current` is given, it is marked with `▲`, and the bar is stretched when it lies outside the range.

# Arguments
- `lower`:      Lower end of the price range.
- `upper`:      Upper end of the price range.
- `value`:      Predicted price, marked with `●`.
- `width`:      Number of characters between the brackets (default 30).
- `current`:    Current price of a listed apartment, marked with `▲` (default `nothing`).

Returns the bar as a `String`, with both ends written as euro amounts.

# Examples
```jldoctest
julia> Project1.range_bar(60, 140, 100; width = 9)
"€60 [====●====] €140"
```
"""
function range_bar(lower::Real, upper::Real, value::Real; width::Int = 30, current = nothing)
    # 1. stop early on input that cannot be drawn
    lower > upper && throw(ArgumentError("lower ($lower) must not be larger than upper ($upper)"))
    width < 1 && throw(ArgumentError("width must be at least 1, got $width"))

    # 2. the bar goes from lower to upper, and is stretched if the current price lies outside
    lo = lower
    hi = upper
    if !isnothing(current)
        lo = min(lower, current)
        hi = max(upper, current)
    end
    # min and max pick the smaller and the larger number, so the current price always fits on the bar

    # 3. turn a price into a place on the bar, from 1 (left end) to width (right end)
    function pos(x)
        # a range of zero width cannot be divided, so the marker goes to the middle
        hi == lo && return cld(width, 2)
        share = clamp((x - lo) / (hi - lo), 0, 1)
        # share = how far x is along the bar, 0 at lo and 1 at hi; clamp keeps it between 0 and 1
        return round(Int, share * (width - 1)) + 1
        # width - 1 steps between the first and the last place, + 1 because Julia counts from 1
    end

    # 4. build the bar: spaces, then '=' for the range, then the markers on top
    chars = fill(' ', width)
    # fill(' ', 5) = a vector of 5 spaces
    chars[pos(lower):pos(upper)] .= '='
    # .= writes '=' into every place from the lower end to the upper end of the range
    chars[pos(value)] = '●'
    if !isnothing(current)
        chars[pos(current)] = '▲'
    end
    # ▲ is set last, so it stays visible when it lands on the same place as ●

    # 5. join everything into one text with the euro amounts at both ends
    return format_eur(lo) * " [" * String(chars) * "] " * format_eur(hi)
end

"""
    plot_price_distribution(df; nbins = 20, io = stdout)

Print a histogram of the price per night of all listings in `df`, to show how the prices in the city are spread.

# Arguments
- `df::DataFrame`:  Processed listings with a `price` column.
- `nbins::Int`:     Number of bars of the histogram (default 20).
- `io::IO`:         Where the chart is printed (default `stdout`, the terminal).

Returns `nothing`, the chart is only printed.
"""
function plot_price_distribution(df::DataFrame; nbins::Int = 20, io::IO = stdout)
    # 1. build the histogram: the prices are sorted into nbins bands of equal width
    chart = histogram(df.price; nbins = nbins, title = "Price per night (EUR)")
    # histogram counts how many listings fall into each price band and draws one bar per band

    # 2. print the chart to io
    println(io, chart)
    # io is the terminal by default; the tests pass an IOBuffer instead, which collects the text so it can be checked

    # 3. nothing to give back, the chart has only been printed
    return nothing
end

"""
    plot_price_by_room_type(df, min_count; io = stdout)

Print a boxplot of the price per night for every room type with at least `min_count` listings,
the room type with the most listings first.

# Arguments
- `df::DataFrame`:  Processed listings with the columns `room_type` and `price`.
- `min_count::Int`: Smallest number of listings a room type needs to get its own box.
- `io::IO`:         Where the chart is printed (default `stdout`, the terminal).

Returns `nothing`, the chart is only printed.
"""
function plot_price_by_room_type(df::DataFrame, min_count::Int; io::IO = stdout)
    # 1. count the listings of every room type
    counts = combine(groupby(df, :room_type), nrow => :n)
    # groupby puts the rows of each room type together, combine with nrow counts them: one row per room type

    # 2. keep only the room types with enough listings, the largest first
    counts = counts[counts.n .>= min_count, :]
    sort!(counts, :n, rev = true)
    rts = counts.room_type
    # rev = true sorts from large to small, so the most common room type is drawn on top

    # 3. stop with a short message if no room type is left, because boxplot cannot draw zero boxes
    if isempty(rts)
        println(io, "No room type has at least $min_count listings.")
        return nothing
    end

    # 4. collect the prices of each kept room type
    data = [df.price[df.room_type .== rt] for rt in rts]
    # for every room type rt, take the prices of the rows whose room_type equals rt: one vector of prices per box

    # 5. draw one box per room type and print the chart
    chart = boxplot(String.(rts), data; title = "Price by room type", xlabel = "EUR")
    # String.() turns the labels into plain text, because CSV reads them as String15, which boxplot does not accept
    println(io, chart)

    return nothing
end

"""
    plot_group_importance(importance; io = stdout)

Print a bar chart of how much each group of predictors adds to the fit of the price model.

# Arguments
- `importance::DataFrame`:  One row per group of predictors with the columns `group` (its name) and `r2_loss`
                            (how much R² drops when the group is left out).
- `io::IO`:                 Where the chart is printed (default `stdout`, the terminal).

Returns `nothing`, the chart is only printed.
"""
function plot_group_importance(importance::DataFrame; io::IO = stdout)
    # 1. stop with a short message if there is nothing to draw, because barplot cannot draw zero bars
    if nrow(importance) == 0
        println(io, "No groups of predictors to show.")
        return nothing
    end

    # 2. a negative loss means the group did not help the fit, so it is shown as 0
    losses = max.(importance.r2_loss, 0)
    # max.(x, 0) goes through every value and replaces it by 0 if it is below 0; barplot stops with an error on negative values

    # 3. draw one bar per group and print the chart
    chart = barplot(String.(importance.group), losses; title = "What drives the price")
    # String.() makes sure the names are plain text, also if they are stored as symbols like :location
    println(io, chart)

    return nothing
end

"""
    plot_predicted_vs_actual(actual, predicted; io = stdout)

Print a scatter plot of the predicted against the actual price of every listing in the test set,
with the diagonal where both are equal.

# Arguments
- `actual::AbstractVector`:     Real prices of the test listings.
- `predicted::AbstractVector`:  Prices the model predicts for the same listings, in the same order.
- `io::IO`:                     Where the chart is printed (default `stdout`, the terminal).

Returns `nothing`, the chart is only printed.
"""
function plot_predicted_vs_actual(actual::AbstractVector, predicted::AbstractVector; io::IO = stdout)
    # 1. both vectors must describe the same listings, and there must be at least one
    length(actual) != length(predicted) && throw(DimensionMismatch("actual has $(length(actual)) values but predicted has $(length(predicted))"))
    isempty(actual) && throw(ArgumentError("actual and predicted must not be empty"))
    # DimensionMismatch is Julia's error for vectors of different lengths, get_r2 uses the same check

    # 2. one dot per listing: the real price from left to right, the predicted price from bottom to top
    chart = scatterplot(actual, predicted; xlabel = "actual EUR", ylabel = "predicted EUR", title = "Test set")

    # 3. add the diagonal where predicted equals actual
    lo, hi = extrema(actual)
    lineplot!(chart, [lo, hi], [lo, hi])
    # extrema gives the smallest and the largest value at once, the line goes from (lo, lo) to (hi, hi)
    # dots above the line were predicted too high, dots below too low

    # 4. print the chart
    println(io, chart)

    return nothing
end
