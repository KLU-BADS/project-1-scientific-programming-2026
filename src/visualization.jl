using Printf

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
