# latest_elixir

A browsable listing of [hexpm/elixir](https://hub.docker.com/r/hexpm/elixir)
Docker tags, generated as a static site and deployed to GitHub Pages nightly.

Docker Hub's tag UI doesn't handle the 634K+ tags in this repository, so this
project fetches recent tags from the Docker Hub API and produces a single
self-contained HTML page with filtering and sorting.

## Running locally

Requires Elixir and Erlang (any recent version).

```sh
mix deps.get
mix run -e "LatestElixir.run()"
open _site/index.html
```

This fetches ~5,000 recent tags from Docker Hub and writes `_site/index.html`.

## Automatic updates

A GitHub Actions workflow runs nightly and deploys the generated page to GitHub
Pages. It can also be triggered manually from the Actions tab.
