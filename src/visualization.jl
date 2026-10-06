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
