defmodule LatestElixir do
  @moduledoc """
  Fetches recent hexpm/elixir Docker Hub tags and generates a static HTML page
  showing the most useful tags prominently.
  """

  @docker_hub_url "https://hub.docker.com/v2/repositories/hexpm/elixir/tags"
  @page_size 100
  @max_pages 200
  # Max pages to fetch per Elixir version during backfill. Each page is 100 tags.
  # Docker Hub has ~8000 tags per Elixir version (many OS date variants), so 20
  # pages (2000 tags) covers the latest Erlang versions across all OS types.
  @max_pages_per_version 20
  @cache_path "_cache/tags.txt"

  @tag_regex ~r/^(\d+\.\d+\.\d+(?:-rc\.\d+)?)-erlang-(\d+(?:\.\d+)*)-(\w+)-(.+?)(-slim)?$/

  def run do
    IO.puts("Fetching tags from Docker Hub...")
    cached_tags = load_cache()
    IO.puts("Loaded #{MapSet.size(cached_tags)} cached tags")

    IO.puts("Fetching newest tags first...")
    newest_tags = fetch_tags(cached_tags, "last_updated")
    merged = MapSet.union(cached_tags, MapSet.new(newest_tags))
    IO.puts("Fetched #{length(newest_tags)} new tags")

    IO.puts("Backfilling per Elixir version...")
    backfill_tags = backfill_by_version(merged)
    merged = MapSet.union(merged, MapSet.new(backfill_tags))
    IO.puts("Backfilled #{length(backfill_tags)} new tags")

    all_tags = MapSet.to_list(merged)
    save_cache(all_tags)
    IO.puts("Total: #{length(all_tags)} tags")

    generate_html(all_tags)
  end

  def generate do
    cached_tags = load_cache()

    if MapSet.size(cached_tags) == 0 do
      IO.puts("No cached tags found. Run LatestElixir.run() first to fetch tags.")
    else
      IO.puts("Using #{MapSet.size(cached_tags)} cached tags")
      generate_html(MapSet.to_list(cached_tags))
    end
  end

  defp generate_html(all_tags) do
    parsed =
      all_tags
      |> Enum.map(&parse_tag/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&(&1.os in ~w(alpine debian ubuntu)))

    IO.puts("Parsed #{length(parsed)} tags")

    prominent = compute_prominent(parsed)

    File.mkdir_p!("_site")
    html = LatestElixir.Html.generate(parsed, prominent)
    File.write!("_site/index.html", html)
    IO.puts("Generated _site/index.html")
  end

  defp load_cache do
    case File.read(@cache_path) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> MapSet.new()

      {:error, _} ->
        MapSet.new()
    end
  end

  defp save_cache(tags) do
    File.mkdir_p!(Path.dirname(@cache_path))
    File.write!(@cache_path, Enum.join(Enum.sort(tags), "\n"))
  end

  defp fetch_tags(cached_tags, ordering) do
    fetch_page("#{@docker_hub_url}?page_size=#{@page_size}&ordering=#{ordering}", [], 1, cached_tags, @max_pages)
  end

  # Discover all Elixir patch versions by querying Docker Hub for each minor
  # version prefix, then fetch tags for each version using the name filter.
  defp backfill_by_version(cached_tags) do
    # Extract known versions from cache
    known_versions =
      cached_tags
      |> MapSet.to_list()
      |> Enum.map(&parse_tag/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.elixir)
      |> Enum.uniq()
      |> Enum.sort(&version_gte?/2)

    IO.puts("  Found #{length(known_versions)} Elixir versions to backfill")

    # Fetch tags for each version using the name filter
    Enum.reduce(known_versions, {[], cached_tags}, fn version, {acc, cached} ->
      prefix = "#{version}-erlang-"
      new_tags = fetch_by_name(prefix, cached)

      if new_tags != [] do
        IO.puts("  #{version}: #{length(new_tags)} new tags")
      end

      {acc ++ new_tags, MapSet.union(cached, MapSet.new(new_tags))}
    end)
    |> elem(0)
  end

  defp fetch_by_name(name_prefix, cached_tags) do
    url = "#{@docker_hub_url}?page_size=#{@page_size}&ordering=name&name=#{URI.encode(name_prefix)}"
    fetch_page(url, [], 1, cached_tags, @max_pages_per_version)
  end

  defp fetch_page(_url, acc, page, _cached, max_pages) when page > max_pages, do: acc

  defp fetch_page(url, acc, page, cached_tags, max_pages) do
    if rem(page, 10) == 1, do: IO.puts("  Fetching page #{page}...")

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        results = body["results"] || []
        tag_names = Enum.map(results, & &1["name"])

        # If every tag on this page is already cached, we've caught up
        all_cached? = tag_names != [] and Enum.all?(tag_names, &MapSet.member?(cached_tags, &1))

        if all_cached? do
          acc
        else
          new_on_page = Enum.reject(tag_names, &MapSet.member?(cached_tags, &1))

          case body["next"] do
            nil -> acc ++ new_on_page
            next_url -> fetch_page(next_url, acc ++ new_on_page, page + 1, cached_tags, max_pages)
          end
        end

      {:ok, %{status: status}} ->
        IO.puts("  Warning: got status #{status}, stopping pagination")
        acc

      {:error, reason} ->
        IO.puts("  Warning: request failed (#{inspect(reason)}), stopping pagination")
        acc
    end
  end

  def parse_tag(tag_name) do
    case Regex.run(@tag_regex, tag_name) do
      [_full, elixir_v, erlang_v, os, os_version, slim] ->
        %{
          tag: tag_name,
          elixir: elixir_v,
          erlang: erlang_v,
          os: os,
          os_version: os_version,
          slim: slim == "-slim",
          elixir_minor: elixir_minor(elixir_v),
          erlang_major: erlang_major(erlang_v),
          rc: String.contains?(elixir_v, "-rc")
        }

      [_full, elixir_v, erlang_v, os, os_version] ->
        %{
          tag: tag_name,
          elixir: elixir_v,
          erlang: erlang_v,
          os: os,
          os_version: os_version,
          slim: false,
          elixir_minor: elixir_minor(elixir_v),
          erlang_major: erlang_major(erlang_v),
          rc: String.contains?(elixir_v, "-rc")
        }

      _ ->
        nil
    end
  end

  defp elixir_minor(version) do
    case String.split(version, ".") do
      [major, minor | _] -> "#{major}.#{minor}"
      _ -> version
    end
  end

  defp erlang_major(version) do
    case String.split(version, ".") do
      [major | _] -> major
      _ -> version
    end
  end

  @doc """
  Compute the prominent tags to display in the hero section.
  Returns the top 3 Elixir minor versions. For each minor version and OS,
  independently picks the latest Elixir patch, then the latest Erlang,
  then the latest OS version (non-slim). This handles the case where the
  very latest Elixir patch or Erlang isn't built for every OS.
  """
  def compute_prominent(parsed) do
    stable = Enum.reject(parsed, & &1.rc)

    # Find top 3 Elixir minor versions
    top_elixir_minors =
      stable
      |> Enum.map(& &1.elixir_minor)
      |> Enum.uniq()
      |> Enum.sort(&version_gte?/2)
      |> Enum.take(3)

    for elixir_minor <- top_elixir_minors do
      minor_tags =
        stable
        |> Enum.filter(&(&1.elixir_minor == elixir_minor && !&1.slim))

      # For each OS, independently find the best tag:
      # latest Elixir patch -> latest Erlang -> latest OS version
      os_tags =
        minor_tags
        |> Enum.group_by(& &1.os)
        |> Enum.map(fn {os, tags} ->
          best_elixir =
            tags
            |> Enum.map(& &1.elixir)
            |> Enum.uniq()
            |> Enum.sort(&version_gte?/2)
            |> List.first()

          best_erlang =
            tags
            |> Enum.filter(&(&1.elixir == best_elixir))
            |> Enum.map(& &1.erlang)
            |> Enum.uniq()
            |> Enum.sort(&version_gte?/2)
            |> List.first()

          best =
            tags
            |> Enum.filter(&(&1.elixir == best_elixir && &1.erlang == best_erlang))
            |> Enum.sort_by(& &1.os_version, :desc)
            |> List.first()

          {os, best}
        end)
        |> Enum.into(%{})

      %{
        elixir_minor: elixir_minor,
        os_tags: os_tags
      }
    end
  end

  @doc """
  Compare two version strings. Returns true if a >= b.
  """
  def version_gte?(a, b) do
    compare_versions(parse_version(a), parse_version(b)) != :lt
  end

  defp parse_version(v) do
    v
    |> String.split(".")
    |> Enum.map(fn part ->
      case Integer.parse(part) do
        {n, _} -> n
        :error -> 0
      end
    end)
  end

  defp compare_versions([], []), do: :eq
  defp compare_versions([], _), do: :lt
  defp compare_versions(_, []), do: :gt

  defp compare_versions([a | rest_a], [b | rest_b]) do
    cond do
      a > b -> :gt
      a < b -> :lt
      true -> compare_versions(rest_a, rest_b)
    end
  end

  @doc """
  Get all unique values for a field from parsed tags, sorted.
  """
  def unique_sorted(parsed, field) do
    parsed
    |> Enum.map(&Map.get(&1, field))
    |> Enum.uniq()
    |> Enum.sort(&version_gte?/2)
  end
end
