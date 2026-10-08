using DataFrames, Printf, Statistics, UnicodePlots

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

"""
    visualize_results(result; io = stdout)

Print the result screen for one apartment: the typical price and its range, for a listed apartment
the assessment of its current price, the expected revenue, and tips to raise the price.

# Arguments
- `result::NamedTuple`: The bundle from `run_prediction_pipeline` with the fields `group` (`:new` or `:listed`),
                        `level`, `price` (`median`, `mean`, `lower`, `upper`), `nights`, `revenue`
                        (`estimate`, `lower`, `upper`), `current_price`, `assessment` (`status`, `difference`),
                        `district`, `room_type`, `tips` and `rating_tips`.
- `io::IO`:             Where the screen is printed (default `stdout`, the terminal).

Returns `nothing`, the screen is only printed.
"""
function visualize_results(result::NamedTuple; io::IO = stdout)
    # 1. header: a listed or a new apartment, then where it is and what kind of place it is
    title = result.group == :listed ? "YOUR LISTING" : "NEW LISTING"
    # cond ? a : b = a if the condition is true, otherwise b (a short if-else in one line)
    printstyled(io, "$title · $(result.district), $(result.room_type)\n"; bold = true)
    println(io, "─"^50)
    # "─"^50 repeats the line character 50 times, a string to the power n means n copies

    # 2. the typical price: the median of comparable listings
    println(io, "Typical price for comparable listings   ", format_eur(result.price.median))

    # 3. the range: level 0.8 means 8 of 10 comparable listings lie inside it
    shown = round(Int, result.level * 10)
    println(io, "Range ($shown of 10 comparable)   ", format_eur(result.price.lower), " to ", format_eur(result.price.upper))
    println(io, "  ", range_bar(result.price.lower, result.price.upper, result.price.median; current = result.current_price))
    # for a new apartment current_price is nothing, so range_bar draws no ▲
    println(io)

    # 4. listed apartments only: how the current price compares with the range, with a coloured message
    if result.group == :listed && !isnothing(result.assessment)
        status = result.assessment.status
        current = format_eur(result.current_price)
        difference = format_eur(result.assessment.difference)
        if status in (:underpriced, :not_price_problem)
            println(io, "Your price $current is below the range by $difference")
        elseif status in (:overpriced, :unexplained_premium)
            println(io, "Your price $current is above the range by $difference")
        else
            println(io, "Your price $current is inside the range")
        end
        # the status says where the price is: two statuses below the range, two above, :in_line inside

        messages = Dict(
            :underpriced         => ("probably underpriced; demand is strong at your price", :green),
            :in_line             => ("in line with comparable listings", :green),
            :not_price_problem   => ("cheap but few bookings; check photos, description, visibility", :yellow),
            :overpriced          => ("possibly overpriced", :red),
            :unexplained_premium => ("guests pay more than the model expects; no action", :default),
        )
        message, color = messages[status]
        printstyled(io, message, "\n"; color = color)
        # every status has one sentence and one colour; an unknown status stops with a KeyError
        println(io)
    end

    # 5. revenue: the mean price times the booked nights per year
    if result.group == :listed
        println(io, "Revenue at ", format_eur(result.price.mean), " × your ", round(Int, result.nights), " nights   ", format_eur(result.revenue.estimate))
        println(io, "  range ", format_eur(result.revenue.lower), " to ", format_eur(result.revenue.upper))
    else
        println(io, "Expected revenue (rough estimate)   ", format_eur(result.revenue.estimate))
    end
    # a new apartment has no booking history, so its nights are only a guess and no range is shown
    println(io)

    # 6. tips: up to 3 missing amenities that would raise the price, then the rating tips
    println(io, "Ways to raise your price")
    if nrow(result.tips) == 0
        println(io, "  No missing amenity has a clear price effect.")
    else
        for row in eachrow(first(result.tips, 3))
            label = CONFIG.amenity_labels[row.amenity]
            println(io, "  + ", label, "   +", format_eur(row.change; digits = 2), " per night (+", round(row.change_pct; digits = 1), "%)")
        end
    end
    # first(table, 3) keeps the first 3 rows; the tips are already sorted from the largest effect down
    # CONFIG.amenity_labels turns the column name :has_AC into the readable "Air conditioning"

    step = CONFIG.rating_tips.step
    for row in eachrow(result.rating_tips)
        name = replace(String(row.score), "review_scores_" => "")
        println(io, "  Listings rated $step higher for $name charge about $(round(row.pct_per_step; digits = 1))% more.")
    end
    # replace cuts the prefix, so :review_scores_cleanliness becomes "cleanliness"
    println(io)

    # 7. footer: the numbers describe comparable listings, they do not promise anything
    println(io, "Based on comparable listings, not a guarantee.")

    return nothing
end

"""
    visualize_general_findings(analysis; io = stdout)

Print the market findings screen: the size and price level of the city's market, the price charts,
how well the models predict, what drives the price, and how close the predictions are on the test set.

# Arguments
- `analysis::NamedTuple`:   The result of `run_analysis_pipeline` with `fits`, `scores`, `df_training` and `df_test`.
- `io::IO`:                 Where the screen is printed (default `stdout`, the terminal).

Returns `nothing`, the screen is only printed.
"""
function visualize_general_findings(analysis::NamedTuple; io::IO = stdout)
    # 1. all listings of the city: the training and the test set together
    df = vcat(analysis.df_training, analysis.df_test)
    # vcat puts the rows of the second table under the rows of the first one

    # 2. header: the city and how many listings the findings are based on
    printstyled(io, "$(uppercase(CONFIG.city)) AIRBNB MARKET · $(nrow(df)) listings\n"; bold = true)
    println(io, "─"^50)

    # 3. overview: the typical price, the middle half of all prices, and the typical yearly revenue
    q1, q3 = quantile(df.price, [0.25, 0.75])
    println(io, "Median price per night   ", format_eur(median(df.price)),
            "  (middle half ", format_eur(q1), " to ", format_eur(q3), ")")
    println(io, "Median yearly revenue    ", format_eur(median(df.estimated_revenue)))
    # quantile at 0.25 and 0.75 gives the two prices between which the middle 50% of all listings lie
    println(io)

    return nothing
end
