defmodule LatestElixir.Html do
  @moduledoc """
  Generates a self-contained HTML page with embedded CSS/JS for browsing
  hexpm/elixir Docker tags.
  """

  def generate(parsed, prominent) do
    json_data = Jason.encode!(Enum.map(parsed, &tag_to_map/1))
    tag_count = length(parsed)
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M UTC")

    elixir_versions = LatestElixir.unique_sorted(parsed, :elixir)
    erlang_versions = LatestElixir.unique_sorted(parsed, :erlang)
    os_list = parsed |> Enum.map(& &1.os) |> Enum.uniq() |> Enum.sort()

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>hexpm/elixir Docker Tags</title>
    <style>
    #{css()}
    </style>
    </head>
    <body>
    <div class="container">
      <header>
        <h1>hexpm/elixir Docker Tags</h1>
        <p class="subtitle">
          A browsable listing of <a href="https://hub.docker.com/r/hexpm/elixir">hexpm/elixir</a>
          tags, updated nightly.
        </p>
      </header>

      <section class="hero">
        <h2>Latest Releases</h2>
        #{prominent_html(prominent)}
      </section>

      <section class="filters">
        <h2>All Tags</h2>
        <div class="filter-row">
          <label>
            Elixir
            <select id="filter-elixir">
              <option value="">All</option>
              #{options_html(elixir_versions)}
            </select>
          </label>
          <label>
            Erlang
            <select id="filter-erlang">
              <option value="">All</option>
              #{options_html(erlang_versions)}
            </select>
          </label>
          <label>
            OS
            <select id="filter-os">
              <option value="">All</option>
              #{options_html(os_list)}
            </select>
          </label>
          <label>
            Size
            <select id="filter-slim">
              <option value="">All</option>
              <option value="false">Full</option>
              <option value="true">Slim</option>
            </select>
          </label>
        </div>
        <p class="result-count">Showing <span id="count">0</span> tags</p>
      </section>

      <table id="tag-table">
        <thead>
          <tr>
            <th class="sortable" data-col="tag">Tag</th>
            <th class="sortable sort-desc" data-col="elixir">Elixir <span class="sort-arrow">&#9660;</span></th>
            <th class="sortable" data-col="erlang">Erlang <span class="sort-arrow"></span></th>
            <th class="sortable" data-col="os">OS <span class="sort-arrow"></span></th>
            <th class="sortable" data-col="os_version">OS Version <span class="sort-arrow"></span></th>
            <th class="sortable" data-col="slim">Slim <span class="sort-arrow"></span></th>
          </tr>
        </thead>
        <tbody id="tag-body"></tbody>
      </table>

      <footer>
        <p>#{tag_count} tags | Last updated: #{timestamp}</p>
        <p>Data from <a href="https://hub.docker.com/r/hexpm/elixir/tags">Docker Hub</a>.
           Source on <a href="https://github.com/fhunleth/latest_elixir">GitHub</a>.</p>
      </footer>
    </div>

    <script>
    const ALL_TAGS = #{json_data};
    #{js()}
    </script>
    </body>
    </html>
    """
  end

  defp tag_to_map(t) do
    %{
      tag: t.tag,
      elixir: t.elixir,
      erlang: t.erlang,
      os: t.os,
      os_version: t.os_version,
      slim: t.slim
    }
  end

  defp prominent_html(prominent) do
    cards =
      Enum.map(prominent, fn %{elixir_minor: elixir_minor, os_tags: os_tags} ->
        os_items =
          os_tags
          |> Enum.sort_by(fn {os, _} -> os end)
          |> Enum.map(fn {_os, tag} ->
            """
            <div class="tag-chip" onclick="copyTag(this)" title="Copy hexpm/elixir:#{tag.tag}">
              <code>#{tag.tag}</code>
            </div>
            """
          end)
          |> Enum.join("\n")

        """
        <div class="card">
          <h3>Elixir #{elixir_minor}</h3>
          #{os_items}
        </div>
        """
      end)
      |> Enum.join("\n")

    """
    <div class="card-grid">
      #{cards}
    </div>
    <p class="copy-hint">Click a tag to copy its full image reference to clipboard</p>
    """
  end

  defp options_html(values) do
    values
    |> Enum.map(fn v -> "<option value=\"#{v}\">#{v}</option>" end)
    |> Enum.join("\n")
  end

  defp css do
    ~S"""
    :root {
      --purple: #4e2a8e;
      --purple-light: #7c5cbf;
      --bg: #f8f7fc;
      --card-bg: #fff;
      --border: #e0dce8;
      --text: #1a1a2e;
      --text-muted: #6b6b80;
      --accent: #4e2a8e;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
    }
    .container { max-width: 1100px; margin: 0 auto; padding: 2rem 1rem; }
    header { text-align: center; margin-bottom: 2rem; }
    h1 { color: var(--purple); font-size: 2rem; }
    .subtitle { color: var(--text-muted); margin-top: 0.5rem; }
    .subtitle a { color: var(--purple-light); }
    h2 { color: var(--purple); margin-bottom: 1rem; font-size: 1.3rem; }
    .hero { margin-bottom: 2.5rem; }
    .card-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 1rem;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1.25rem;
    }
    .card h3 { color: var(--purple); margin-bottom: 0.25rem; }
    .card-sub { color: var(--text-muted); font-size: 0.9rem; margin-bottom: 0.75rem; }
    .tag-chip {
      display: inline-block;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 4px;
      padding: 0.3rem 0.6rem;
      margin: 0.2rem;
      cursor: pointer;
      transition: background 0.15s;
      font-size: 0.85rem;
    }
    .tag-chip:hover { background: #ede8f5; }
    .tag-chip.copied { background: #d4edda; border-color: #a3d9b1; }
    .copy-hint { color: var(--text-muted); font-size: 0.8rem; margin-top: 0.5rem; }
    .filters { margin-bottom: 1.5rem; }
    .filter-row {
      display: flex; flex-wrap: wrap; gap: 1rem; margin-bottom: 0.75rem;
    }
    .filter-row label {
      display: flex; flex-direction: column; font-size: 0.85rem;
      color: var(--text-muted); font-weight: 600;
    }
    .filter-row select {
      margin-top: 0.25rem; padding: 0.4rem 0.6rem; border: 1px solid var(--border);
      border-radius: 4px; font-size: 0.9rem; min-width: 150px;
    }
    .result-count { color: var(--text-muted); font-size: 0.85rem; }
    table {
      width: 100%; border-collapse: collapse; background: var(--card-bg);
      border: 1px solid var(--border); border-radius: 8px; overflow: hidden;
    }
    th {
      background: var(--purple); color: #fff; padding: 0.6rem 0.75rem;
      text-align: left; font-size: 0.85rem; font-weight: 600;
    }
    th.sortable { cursor: pointer; user-select: none; white-space: nowrap; }
    th.sortable:hover { background: var(--purple-light); }
    .sort-arrow { font-size: 0.7rem; margin-left: 0.25rem; opacity: 0.6; }
    th.sort-asc .sort-arrow, th.sort-desc .sort-arrow { opacity: 1; }
    td {
      padding: 0.5rem 0.75rem; border-top: 1px solid var(--border);
      font-size: 0.85rem;
    }
    td:first-child { font-family: monospace; font-size: 0.8rem; }
    tr:hover td { background: #f3f0fa; }
    footer {
      margin-top: 2.5rem; text-align: center; color: var(--text-muted);
      font-size: 0.8rem;
    }
    footer a { color: var(--purple-light); }
    @media (max-width: 600px) {
      .card-grid { grid-template-columns: 1fr; }
      .filter-row { flex-direction: column; }
      .filter-row select { min-width: auto; width: 100%; }
    }
    """
  end

  defp js do
    ~S"""
    // Sort state: array of {col, dir} for multi-key sorting
    // Default: elixir desc, erlang desc, os asc, os_version desc, slim asc
    let sortKeys = [
      {col: 'elixir', dir: 'desc'},
      {col: 'erlang', dir: 'desc'},
      {col: 'os', dir: 'asc'},
      {col: 'os_version', dir: 'desc'},
      {col: 'slim', dir: 'asc'}
    ];

    function parseVersion(v) {
      return v.split('.').map(p => parseInt(p, 10) || 0);
    }

    function cmpVersion(a, b) {
      const pa = parseVersion(a), pb = parseVersion(b);
      for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
        const va = pa[i] || 0, vb = pb[i] || 0;
        if (va !== vb) return va - vb;
      }
      return 0;
    }

    const versionCols = new Set(['elixir', 'erlang', 'os_version']);

    function cmpField(a, b, col) {
      const va = a[col], vb = b[col];
      if (col === 'slim') return (va === vb) ? 0 : va ? 1 : -1;
      if (versionCols.has(col)) return cmpVersion(va, vb);
      return va < vb ? -1 : va > vb ? 1 : 0;
    }

    function sortData(data) {
      return data.slice().sort((a, b) => {
        for (const {col, dir} of sortKeys) {
          const c = cmpField(a, b, col);
          if (c !== 0) return dir === 'desc' ? -c : c;
        }
        return 0;
      });
    }

    function updateSortUI() {
      document.querySelectorAll('th.sortable').forEach(th => {
        th.classList.remove('sort-asc', 'sort-desc');
        th.querySelector('.sort-arrow').textContent = '';
      });
      if (sortKeys.length > 0) {
        const primary = sortKeys[0];
        const th = document.querySelector(`th[data-col="${primary.col}"]`);
        if (th) {
          th.classList.add(primary.dir === 'asc' ? 'sort-asc' : 'sort-desc');
          th.querySelector('.sort-arrow').innerHTML = primary.dir === 'asc' ? '&#9650;' : '&#9660;';
        }
      }
    }

    function handleSort(col) {
      const existing = sortKeys.findIndex(k => k.col === col);
      if (existing === 0) {
        // Toggle direction of primary sort
        sortKeys[0].dir = sortKeys[0].dir === 'asc' ? 'desc' : 'asc';
      } else {
        // Move/add this column to primary position
        if (existing > 0) sortKeys.splice(existing, 1);
        sortKeys.unshift({col, dir: 'desc'});
      }
      updateSortUI();
      applyFilters();
    }

    function applyFilters() {
      const elixir = document.getElementById('filter-elixir').value;
      const erlang = document.getElementById('filter-erlang').value;
      const os = document.getElementById('filter-os').value;
      const slim = document.getElementById('filter-slim').value;

      let filtered = ALL_TAGS.filter(t => {
        if (elixir && t.elixir !== elixir) return false;
        if (erlang && t.erlang !== erlang) return false;
        if (os && t.os !== os) return false;
        if (slim !== '' && String(t.slim) !== slim) return false;
        return true;
      });

      filtered = sortData(filtered);

      const tbody = document.getElementById('tag-body');
      tbody.innerHTML = filtered.slice(0, 500).map(t =>
        `<tr>
          <td>${t.tag}</td>
          <td>${t.elixir}</td>
          <td>${t.erlang}</td>
          <td>${t.os}</td>
          <td>${t.os_version}</td>
          <td>${t.slim ? 'Yes' : ''}</td>
        </tr>`
      ).join('');

      const countEl = document.getElementById('count');
      countEl.textContent = filtered.length > 500
        ? `${filtered.length} (showing first 500)`
        : filtered.length;
    }

    function copyTag(el) {
      const text = el.querySelector('code').textContent;
      navigator.clipboard.writeText('hexpm/elixir:' + text).then(() => {
        el.classList.add('copied');
        setTimeout(() => el.classList.remove('copied'), 1500);
      });
    }

    document.querySelectorAll('.filter-row select').forEach(sel => {
      sel.addEventListener('change', applyFilters);
    });

    document.querySelectorAll('th.sortable').forEach(th => {
      th.addEventListener('click', () => handleSort(th.dataset.col));
    });

    updateSortUI();
    applyFilters();
    """
  end
end
