# Project1.jl

<!-- DO NOT EDIT BELOW -->
[![Tests](../../actions/workflows/tests.yml/badge.svg)](../../actions/workflows/tests.yml)
[![Documentation](../../actions/workflows/docs.yml/badge.svg)](../../actions/workflows/docs.yml)
<!-- DO NOT EDIT ABOVE -->


## Overview

<!-- DESCRIBE PROJECT PURPOSE BELOW -->
Our first idea is to use a regression model on a data set to create a model projecting demand and pricing. We considered the possibility of using a data set on hotel bookings and use factors including number of rooms booked on each day, room prices, and customer reviews as the input for a regression model and provide pricing recommendations and give the main reasons that influence the room price including the location, cleanliness of the room, amenities, etc for a certain hotel to give an insight into possible improvements a hotel owner could make to increase the profit per room. 
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
Once the package is cloned you can run:

```julia
using Project1
hello()
```
to print "Hello World" to standard output.
<!-- DESCRIBE THE ESSENTIAL USAGE ABOVE -->

## Tests

<!-- DO NOT EDIT BELOW -->
Tests are run automatically on GitHub for every push to `main` and on every pull request.

> [!TIP]
> To run the tests locally, run
> ```bash
> julia --project=. -e 'using Pkg; Pkg.test()'
> ```
 
<!-- DO NOT EDIT ABOVE -->


## Documentation

<!-- DO NOT EDIT BELOW -->
The [online documentation](https://klu-bads.github.io/project-1-scientific-programming-2026/) is automatically built and published to GitHub Pages on every push to `main`.

> [!TIP]
> To build the documentation locally, run
> ```bash
> julia --project=docs docs/make.jl
> ```
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
