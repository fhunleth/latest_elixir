defmodule LatestElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :latest_elixir,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: false,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"}
    ]
  end

  defp aliases do
    [
      # Fetch the latest tags from Docker Hub and regenerate the static site.
      site: ["run -e LatestElixir.run()", "run -e LatestErlang.run()"],
      # Regenerate the static site from the cached tags, without fetching.
      gen: ["run -e LatestElixir.generate()", "run -e LatestErlang.generate()"],
      # Serve the generated _site over HTTP for local previewing.
      serve: ["run --no-halt -e LatestElixir.Server.start()"]
    ]
  end
end
