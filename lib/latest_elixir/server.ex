defmodule LatestElixir.Server do
  @moduledoc """
  Minimal static file server for the generated `_site` directory, used for
  local previewing. Built on Erlang's bundled `:inets` httpd, so it needs no
  extra dependencies. Serving over HTTP (rather than opening the files as
  `file://` URLs) is required because the pages load their tag data with
  `fetch()`, which browsers block for local files.
  """

  @default_port 8000
  @doc_root "_site"

  @doc """
  Start the static file server on `port` (default #{@default_port}) and block.

  Intended to be invoked via `mix serve`, which keeps the VM alive with
  `--no-halt` so the server keeps running until Ctrl+C.
  """
  def start(port \\ @default_port) do
    unless File.dir?(@doc_root) do
      IO.puts("No #{@doc_root}/ directory found. Run `mix site` first to build it.")
      System.halt(1)
    end

    {:ok, _} = Application.ensure_all_started(:inets)
    root = String.to_charlist(Path.expand(@doc_root))

    config = [
      port: port,
      bind_address: {127, 0, 0, 1},
      server_name: ~c"latest_elixir",
      server_root: root,
      document_root: root,
      directory_index: [~c"index.html"],
      mime_types: [
        {~c"html", ~c"text/html"},
        {~c"txt", ~c"text/plain"},
        {~c"css", ~c"text/css"},
        {~c"js", ~c"application/javascript"},
        {~c"json", ~c"application/json"}
      ]
    ]

    case :inets.start(:httpd, config) do
      {:ok, _pid} ->
        IO.puts("Serving #{Path.expand(@doc_root)} at http://localhost:#{port}/  (Ctrl+C to stop)")

      {:error, reason} ->
        IO.puts("Failed to start server on port #{port}: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
