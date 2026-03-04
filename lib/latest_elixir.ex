defmodule LatestElixir do
  @moduledoc """
  Fetches recent hexpm/elixir Docker Hub tags and generates a static HTML page
  showing the most useful tags prominently.
  """

  @docker_hub_url "https://hub.docker.com/v2/repositories/hexpm/elixir/tags"
  @page_size 100
  @max_pages 50

  @tag_regex ~r/^(\d+\.\d+\.\d+(?:-rc\.\d+)?)-erlang-(\d+(?:\.\d+)*)-(\w+)-(.+?)(-slim)?$/

  def run do
    IO.puts("Fetching tags from Docker Hub...")
    tags = fetch_all_tags()
    IO.puts("Fetched #{length(tags)} tags")

    parsed =
      tags
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

  defp fetch_all_tags do
    fetch_page("#{@docker_hub_url}?page_size=#{@page_size}&ordering=last_updated", [], 1)
  end

  defp fetch_page(_url, acc, page) when page > @max_pages, do: acc

  defp fetch_page(url, acc, page) do
    IO.puts("  Fetching page #{page}...")

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        results = body["results"] || []
        tag_names = Enum.map(results, & &1["name"])

        case body["next"] do
          nil -> acc ++ tag_names
          next_url -> fetch_page(next_url, acc ++ tag_names, page + 1)
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
  Returns the top 3 Elixir minor versions, each with their latest Erlang,
  across alpine, ubuntu, and debian (non-slim).
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

    # For each Elixir minor, find the latest patch
    for elixir_minor <- top_elixir_minors do
      elixir_tags = Enum.filter(stable, &(&1.elixir_minor == elixir_minor))

      latest_elixir =
        elixir_tags
        |> Enum.map(& &1.elixir)
        |> Enum.uniq()
        |> Enum.sort(&version_gte?/2)
        |> List.first()

      latest_tags = Enum.filter(elixir_tags, &(&1.elixir == latest_elixir))

      # Find latest Erlang for this Elixir
      latest_erlang =
        latest_tags
        |> Enum.map(& &1.erlang)
        |> Enum.uniq()
        |> Enum.sort(&version_gte?/2)
        |> List.first()

      best_tags = Enum.filter(latest_tags, &(&1.erlang == latest_erlang && !&1.slim))

      # Pick one tag per OS family, preferring the latest os_version
      os_tags =
        best_tags
        |> Enum.group_by(& &1.os)
        |> Enum.map(fn {os, tags} ->
          best =
            tags
            |> Enum.sort_by(& &1.os_version, :desc)
            |> List.first()

          {os, best}
        end)
        |> Enum.into(%{})

      %{
        elixir: latest_elixir,
        erlang: latest_erlang,
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
