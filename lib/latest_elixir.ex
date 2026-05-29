defmodule LatestElixir do
  @moduledoc """
  Fetches recent hexpm/elixir Docker Hub tags and generates a static HTML page
  showing the most useful tags prominently.
  """

  import Bitwise

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
    IO.puts("Loaded #{map_size(cached_tags)} cached tags")

    IO.puts("Fetching newest tags first...")
    newest_tags = fetch_tags(cached_tags, "last_updated")
    merged = Enum.into(newest_tags, cached_tags)
    IO.puts("Fetched #{length(newest_tags)} new/updated tags")

    IO.puts("Backfilling per Elixir version...")
    backfill_tags = backfill_by_version(merged)
    merged = Enum.into(backfill_tags, merged)
    IO.puts("Backfilled #{length(backfill_tags)} new/updated tags")

    save_cache(merged)
    IO.puts("Total: #{map_size(merged)} tags")

    generate_html(merged)
  end

  def generate do
    cached_tags = load_cache()

    if map_size(cached_tags) == 0 do
      IO.puts("No cached tags found. Run LatestElixir.run() first to fetch tags.")
    else
      IO.puts("Using #{map_size(cached_tags)} cached tags")
      generate_html(cached_tags)
    end
  end

  defp generate_html(tags_map) do
    parsed =
      tags_map
      |> Enum.map(fn {name, arches} -> parse_tag(name, arches) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&(&1.os in ~w(alpine debian ubuntu)))

    IO.puts("Parsed #{length(parsed)} tags")

    prominent = compute_prominent(parsed)

    File.mkdir_p!("_site")
    html = LatestElixir.Html.generate(parsed, prominent)
    File.write!("_site/index.html", html)
    IO.puts("Generated _site/index.html")

    # Tag data is served as a separate compact file the page fetches on load,
    # rather than inlined into the HTML, so the initial page stays tiny.
    write_data_file("_site/elixir-data.txt", parsed)
    IO.puts("Generated _site/elixir-data.txt")

    tags_txt = parsed |> Enum.map(& &1.tag) |> Enum.sort() |> Enum.join("\n")
    File.write!("_site/elixir-tags.txt", tags_txt <> "\n")
    IO.puts("Generated _site/elixir-tags.txt")
  end

  # Compact data file consumed by the page's JavaScript. Line 1 is the
  # architecture dictionary (comma-separated, defines bit positions); each
  # remaining line is "tag<TAB>bitmask". The page reconstructs the Elixir,
  # Erlang, OS, etc. columns from the tag string, so only the tag and its
  # architecture bits need to be shipped.
  defp write_data_file(path, parsed) do
    arch_dict =
      parsed
      |> Enum.flat_map(& &1.arches)
      |> Enum.uniq()
      |> Enum.sort()

    arch_index = arch_dict |> Enum.with_index() |> Map.new()

    rows =
      parsed
      |> Enum.sort_by(& &1.tag)
      |> Enum.map(fn t -> "#{t.tag}\t#{arch_bitmask(t.arches, arch_index)}" end)

    File.write!(path, Enum.join([Enum.join(arch_dict, ",") | rows], "\n") <> "\n")
  end

  defp arch_bitmask(arches, arch_index) do
    Enum.reduce(arches, 0, fn arch, acc -> acc ||| 1 <<< Map.fetch!(arch_index, arch) end)
  end

  # The cache stores one tag per line as "name<TAB>arch1,arch2". Older caches
  # written before architectures were captured have no tab; those tags load
  # with an empty architecture list and get refreshed as they're re-fetched.
  defp load_cache do
    case File.read(@cache_path) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> Map.new(&parse_cache_line/1)

      {:error, _} ->
        %{}
    end
  end

  defp parse_cache_line(line) do
    case String.split(line, "\t", parts: 2) do
      [name, arches] -> {name, String.split(arches, ",", trim: true)}
      [name] -> {name, []}
    end
  end

  defp save_cache(tags_map) do
    File.mkdir_p!(Path.dirname(@cache_path))

    contents =
      tags_map
      |> Enum.sort_by(fn {name, _arches} -> name end)
      |> Enum.map_join("\n", fn {name, arches} -> "#{name}\t#{Enum.join(arches, ",")}" end)

    File.write!(@cache_path, contents)
  end

  defp fetch_tags(cached_tags, ordering) do
    fetch_page(
      "#{@docker_hub_url}?page_size=#{@page_size}&ordering=#{ordering}",
      [],
      1,
      cached_tags,
      @max_pages
    )
  end

  # Discover all Elixir patch versions by querying Docker Hub for each minor
  # version prefix, then fetch tags for each version using the name filter.
  defp backfill_by_version(cached_tags) do
    # Extract known versions from cache
    known_versions =
      cached_tags
      |> Map.keys()
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
        IO.puts("  #{version}: #{length(new_tags)} new/updated tags")
      end

      {acc ++ new_tags, Enum.into(new_tags, cached)}
    end)
    |> elem(0)
  end

  defp fetch_by_name(name_prefix, cached_tags) do
    url =
      "#{@docker_hub_url}?page_size=#{@page_size}&ordering=name&name=#{URI.encode(name_prefix)}"

    fetch_page(url, [], 1, cached_tags, @max_pages_per_version)
  end

  defp fetch_page(_url, acc, page, _cached, max_pages) when page > max_pages, do: acc

  defp fetch_page(url, acc, page, cached_tags, max_pages) do
    if rem(page, 10) == 1, do: IO.puts("  Fetching page #{page}...")

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        results = body["results"] || []

        # Tags that are new, or whose architecture set has changed since we
        # cached them. The latter matters because a tag is often published for
        # one architecture first and gains a second one after a later scan;
        # that re-push bumps the tag's last_updated, so the last_updated
        # ordering re-surfaces it here and we refresh its architectures.
        changed =
          results
          |> Enum.map(&{&1["name"], extract_arches(&1)})
          |> Enum.reject(fn {name, arches} -> Map.get(cached_tags, name) == arches end)

        # Caught up once a full page shows no new tags and no architecture
        # changes, so steady-state runs still stop early.
        if results != [] and changed == [] do
          acc
        else
          case body["next"] do
            nil -> acc ++ changed
            next_url -> fetch_page(next_url, acc ++ changed, page + 1, cached_tags, max_pages)
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

  # Architectures Docker Hub reports for a tag. The images list can include
  # attestation manifests with architecture "unknown"; those are dropped.
  defp extract_arches(result) do
    (result["images"] || [])
    |> Enum.filter(&(&1["status"] == "active"))
    |> Enum.map(& &1["architecture"])
    |> Enum.reject(&(&1 in [nil, "", "unknown"]))
    |> Enum.uniq()
    |> Enum.sort()
  end

  def parse_tag(tag_name, arches \\ []) do
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
          rc: String.contains?(elixir_v, "-rc"),
          arches: arches
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
          rc: String.contains?(elixir_v, "-rc"),
          arches: arches
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
  then the latest OS version (non-slim). Only multi-arch (amd64 + arm64)
  builds are considered so the highlighted tags run everywhere; this also
  skips the case where the very latest patch was only built for one
  architecture. Falls back to all tags if none are multi-arch.
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
          multi_arch = Enum.filter(tags, &multi_arch?/1)
          candidates = if multi_arch == [], do: tags, else: multi_arch

          best_elixir =
            candidates
            |> Enum.map(& &1.elixir)
            |> Enum.uniq()
            |> Enum.sort(&version_gte?/2)
            |> List.first()

          best_erlang =
            candidates
            |> Enum.filter(&(&1.elixir == best_elixir))
            |> Enum.map(& &1.erlang)
            |> Enum.uniq()
            |> Enum.sort(&version_gte?/2)
            |> List.first()

          best =
            candidates
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

  # A tag is multi-arch when it has both amd64 and arm64 builds.
  defp multi_arch?(t), do: "amd64" in t.arches and "arm64" in t.arches

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
