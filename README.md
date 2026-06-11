# latest_elixir

> The most up to date list of tags is now at <https://bob.hex.pm/docker>.

A browsable listing of [hexpm/elixir](https://hub.docker.com/r/hexpm/elixir)
Docker tags, generated as a static site and deployed to GitHub Pages nightly.

Docker Hub's tag UI doesn't handle the 634K+ tags in this repository, so this
project fetches recent tags from the Docker Hub API and produces a small HTML
page with filtering and sorting. The tag data itself is written to a separate
`*-data.txt` file that the page fetches on load, so the page stays tiny even
with hundreds of thousands of tags.

## Running locally

Requires Elixir and Erlang (any recent version).

```sh
mix deps.get
mix site     # fetch tags from Docker Hub and build _site/
mix gen      # rebuild _site/ from the cached tags, without fetching
mix serve    # serve _site/ at http://localhost:8000/
```

`mix site` fetches tags and writes `_site/index.html`, `_site/erlang.html`, and
the `*-data.txt` data files. `mix gen` rebuilds those same files from the
already-cached tags (handy while iterating on the page itself). Because the pages load their data with `fetch()`,
they must be served over HTTP — opening `_site/index.html` directly as a
`file://` URL won't work (the browser blocks the fetch). `mix serve` starts a
small local HTTP server (Erlang's bundled `:inets`, no extra dependency) for
exactly this; press Ctrl+C to stop it.

## Automatic updates

A GitHub Actions workflow runs nightly and deploys the generated page to GitHub
Pages. It can also be triggered manually from the Actions tab.
