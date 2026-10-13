# HostWise.jl

<!-- DO NOT EDIT BELOW -->

[![Tests](../../actions/workflows/tests.yml/badge.svg)](../../actions/workflows/tests.yml)
[![Documentation](../../actions/workflows/docs.yml/badge.svg)](../../actions/workflows/docs.yml)

<!-- DO NOT EDIT ABOVE -->

## Overview

<!-- DESCRIBE PROJECT PURPOSE BELOW -->

This project uses Inside Airbnb listing data, starting with Athens, Greece, with the design allowing more cities to be added later, to estimate a fair nightly price and expected yearly revenue for an apartment, based on features like bedrooms, bathrooms, amenities and location, plus host details like superhost status. It's aimed at hosts and investors deciding what to charge or whether to list a property, and at guests checking whether a listing is priced fairly.

<!-- DESCRIBE PROJECT PURPOSE ABOVE  -->

## Getting started

<!-- DO NOT EDIT BELOW -->

Clone the repository and start Julia in the project folder:

```bash
git clone https://github.com/KLU-BADS/project-1-scientific-programming-2026.git
cd project-1-scientific-programming-2026
julia --project=.
```

<!-- DO NOT EDIT ABOVE -->

<!-- DESCRIBE THE ESSENTIAL USAGE BELOW -->

Start the program from a terminal in the project folder:

```bash
julia src/main.jl
```

The first start installs the packages and takes a few minutes; later starts are faster. The menus need a real terminal (arrow keys, Enter, `q` to leave).

1. **Which city?** Choose one of the cities whose listings file is in `data/raw` (currently Athens, Barcelona and Madrid). The program then cleans the data and fits the models.
2. **Main menu**
   - **Market findings**: prices, price per room type, how well the models predict and what drives the price.
   - **Price a new apartment**: answer a few questions (size, location, amenities, Superhost) and get a recommended price, a price range of comparable listings, the expected revenue and tips to raise the price.
   - **Check my listed apartment**: the same questions plus your current price, rating and booked nights; the program tells you whether your price is in line with comparable listings.
   - **Change city**: back to the city selection.
   - **Exit**: ends the program.
3. Before the prediction, all answers are shown once to confirm them. After the result, it can be saved as `hostwise_result.txt` in the project folder.

### Adding a city

No code has to be changed, only the data and the configuration:

1. Download the **detailed** listings file (`listings.csv.gz`) of the city from [Inside Airbnb](https://insideairbnb.com/get-the-data/), unzip it and save it as `data/raw/<city>_listings.csv`, with the city name in lowercase (e.g. `vienna_listings.csv`).
2. Add the city to `cities` in `src/config.jl` with its centre and the currency of its prices:
   ```julia
   "Vienna" => (center = (latitude = 48.2082, longitude = 16.3738), currency = "EUR"),
   ```
   The name must match the file name (`"Vienna"` → `vienna_listings.csv`).
3. Inside Airbnb gives the prices in the **local currency** of the city (the `$` sign in the file is only formatting). For a city outside the euro zone, use its currency code and add its rate to `exchange_rates` in `currency_rules`, e.g. `"GBP" => 1.17` (value of 1 GBP in EUR). All prices in the program are shown in euros.
4. Start the program: the new city appears in the city menu. Run `julia --project=. -e 'using Pkg; Pkg.test()'` to make sure nothing else changed.
<!-- DESCRIBE THE ESSENTIAL USAGE ABOVE -->

## Tests

<!-- DO NOT EDIT BELOW -->

Tests are run automatically on GitHub for every push to `main` and on every pull request.

> [!TIP]
> To run the tests locally, run
>
> ```bash
> julia --project=. -e 'using Pkg; Pkg.test()'
> ```

<!-- DO NOT EDIT ABOVE -->

## Documentation

<!-- DO NOT EDIT BELOW -->

The [online documentation](https://klu-bads.github.io/project-1-scientific-programming-2026/) is automatically built and published to GitHub Pages on every push to `main`.

> [!TIP]
> To build the documentation locally, run
>
> ```bash
> julia --project=docs docs/make.jl
> ```
>
> and open `docs/build/index.html` in a browser.
>
> If building the documentation fails, run the tests locally before.

<!-- DO NOT EDIT ABOVE -->

## Contributing

<!-- DO NOT EDIT BELOW -->

See [CONTRIBUTING.md](CONTRIBUTING.md).

<!-- DO NOT EDIT ABOVE -->

## License

<!-- DO NOT EDIT BELOW -->

MIT. See [LICENSE](LICENSE).

<!-- DO NOT EDIT ABOVE -->
