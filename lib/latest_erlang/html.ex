defmodule LatestErlang.Html do
  @moduledoc """
  Generates a self-contained HTML page with embedded CSS/JS for browsing
  hexpm/erlang Docker tags.
  """

  def generate(parsed, prominent) do
    tag_count = length(parsed)
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M UTC")

    erlang_versions = LatestErlang.unique_sorted(parsed, :erlang)
    os_list = parsed |> Enum.map(& &1.os) |> Enum.uniq() |> Enum.sort()

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>hexpm/erlang Docker Tags</title>
    <style>
    #{css()}
    </style>
    </head>
    <body>
    <div class="container">
      <nav class="nav-bar">
        <a href="index.html" class="nav-link">Elixir Tags</a>
        <a href="erlang.html" class="nav-link active">Erlang Tags</a>
      </nav>

      <header>
        <h1>hexpm/erlang Docker Tags</h1>
        <p class="subtitle">
          A browsable listing of <a href="https://hub.docker.com/r/hexpm/erlang">hexpm/erlang</a>
          tags, updated nightly.
        </p>
      </header>

      <div class="banner">
        Important: The most up to date list of tags is now at <a href="https://bob.hex.pm/docker">https://bob.hex.pm/docker</a>.
      </div>

      <section class="hero">
        <h2>Latest Releases</h2>
        #{prominent_html(prominent)}
        <p class="note">
          These highlight the latest stable builds available for both
          <code>amd64</code> and <code>arm64</code>. Release candidates and
          images built for only one architecture aren't shown here &mdash;
          find them by searching all tags below.
        </p>
      </section>

      <section class="filters">
        <h2>All Tags</h2>
        <div class="filter-row">
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
          <label>
            Architecture
            <select id="filter-arch">
              <option value="">All</option>
              <option value="multi">amd64 + arm64</option>
              <option value="amd64-only">amd64 only</option>
              <option value="arm64-only">arm64 only</option>
            </select>
          </label>
        </div>
        <p class="result-count">Showing <span id="count">0</span> tags</p>
      </section>

      <table id="tag-table">
        <thead>
          <tr>
            <th class="sortable" data-col="tag">Tag <span class="sort-arrow"></span></th>
            <th class="sortable sort-desc" data-col="erlang">Erlang <span class="sort-arrow">&#9660;</span></th>
            <th class="sortable" data-col="os">OS <span class="sort-arrow"></span></th>
            <th class="sortable" data-col="os_version">OS Version <span class="sort-arrow"></span></th>
            <th class="sortable" data-col="slim">Slim <span class="sort-arrow"></span></th>
            <th class="sortable" data-col="arches">Arch <span class="sort-arrow"></span></th>
          </tr>
        </thead>
        <tbody id="tag-body"></tbody>
      </table>

      <footer>
        <p>#{tag_count} tags | Last updated: #{timestamp}</p>
        <p>Data from <a href="https://hub.docker.com/r/hexpm/erlang/tags">Docker Hub</a>.
           Source on <a href="https://github.com/fhunleth/latest_elixir">GitHub</a>.
           <a href="erlang-tags.txt">Download tags as text</a>.</p>
      </footer>
    </div>

    <script>
    #{js()}
    </script>
    </body>
    </html>
    """
  end

  defp prominent_html(prominent) do
    cards =
      Enum.map(prominent, fn %{erlang_major: erlang_major, os_tags: os_tags} ->
        os_items =
          os_tags
          |> Enum.sort_by(fn {os, _} -> os end)
          |> Enum.map(fn {_os, tag} ->
            """
            <div class="tag-chip" onclick="copyTag(this)" title="Copy hexpm/erlang:#{tag.tag}">
              <code>#{tag.tag}</code>
            </div>
            """
          end)
          |> Enum.join("\n")

        """
        <div class="card">
          <h3>OTP #{erlang_major}</h3>
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
      --accent: #a0230a;
      --accent-light: #c94c33;
      --bg: #fdf7f6;
      --card-bg: #fff;
      --border: #e8dcd9;
      --text: #1a1a2e;
      --text-muted: #6b6b80;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
    }
    .container { max-width: 1100px; margin: 0 auto; padding: 2rem 1rem; }
    .nav-bar {
      display: flex; gap: 0.5rem; margin-bottom: 1.5rem;
      border-bottom: 2px solid var(--border); padding-bottom: 0.5rem;
    }
    .nav-link {
      padding: 0.4rem 1rem; border-radius: 4px 4px 0 0;
      text-decoration: none; color: var(--text-muted); font-weight: 600;
      font-size: 0.95rem;
    }
    .nav-link:hover { color: var(--accent); background: rgba(160,35,10,0.05); }
    .nav-link.active {
      color: var(--accent); border-bottom: 2px solid var(--accent);
      margin-bottom: -2px;
    }
    header { text-align: center; margin-bottom: 2rem; }
    h1 { color: var(--accent); font-size: 2rem; }
    .subtitle { color: var(--text-muted); margin-top: 0.5rem; }
    .subtitle a { color: var(--accent-light); }
    h2 { color: var(--accent); margin-bottom: 1rem; font-size: 1.3rem; }
    .banner {
      margin-bottom: 2rem; padding: 0.9rem 1.25rem; font-size: 1rem;
      background: #fff8e1; border: 1px solid #f0d98c;
      border-left: 4px solid #e6b800; border-radius: 6px;
    }
    .banner a { color: var(--purple); font-weight: 600; }
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
    .card h3 { color: var(--accent); margin-bottom: 0.25rem; }
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
    .tag-chip:hover { background: #f5e0dc; }
    .tag-chip.copied { background: #d4edda; border-color: #a3d9b1; }
    .copy-hint { color: var(--text-muted); font-size: 0.8rem; margin-top: 0.5rem; }
    .note {
      margin-top: 1rem; padding: 0.75rem 1rem; font-size: 0.85rem;
      color: var(--text-muted); background: rgba(160,35,10,0.05);
      border-left: 3px solid var(--accent-light); border-radius: 0 4px 4px 0;
    }
    .note code {
      background: var(--bg); padding: 0.05rem 0.3rem; border-radius: 3px;
      font-size: 0.8rem;
    }
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
      background: var(--accent); color: #fff; padding: 0.6rem 0.75rem;
      text-align: left; font-size: 0.85rem; font-weight: 600;
    }
    th.sortable { cursor: pointer; user-select: none; white-space: nowrap; }
    th.sortable:hover { background: var(--accent-light); }
    .sort-arrow { font-size: 0.7rem; margin-left: 0.25rem; opacity: 0.6; }
    th.sort-asc .sort-arrow, th.sort-desc .sort-arrow { opacity: 1; }
    td {
      padding: 0.5rem 0.75rem; border-top: 1px solid var(--border);
      font-size: 0.85rem;
    }
    td:first-child { font-family: monospace; font-size: 0.8rem; }
    tr:hover td { background: #faf0ee; }
    footer {
      margin-top: 2.5rem; text-align: center; color: var(--text-muted);
      font-size: 0.8rem;
    }
    footer a { color: var(--accent-light); }
    @media (max-width: 600px) {
      .card-grid { grid-template-columns: 1fr; }
      .filter-row { flex-direction: column; }
      .filter-row select { min-width: auto; width: 100%; }
    }
    """
  end

  defp js do
    ~S"""
    // Tag data is fetched from a separate compact file rather than inlined,
    // keeping this page small. Each data line is "tag<TAB>bitmask"; the Erlang,
    // OS, OS-version and slim columns are reconstructed from the tag.
    let ALL_TAGS = [];
    const TAG_RE = /^(\d+\.\d+(?:\.\d+)*(?:-rc\d+)?)-(\w+)-(.+?)(-slim)?$/;

    async function loadData() {
      const resp = await fetch('erlang-data.txt');
      const text = await resp.text();
      const lines = text.split('\n');
      const archDict = lines[0] ? lines[0].split(',').filter(Boolean) : [];
      const tags = [];
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        if (!line) continue;
        const tab = line.indexOf('\t');
        const name = tab === -1 ? line : line.slice(0, tab);
        const bits = tab === -1 ? 0 : (parseInt(line.slice(tab + 1), 10) || 0);
        const m = TAG_RE.exec(name);
        if (!m) continue;
        const arches = [];
        for (let b = 0; b < archDict.length; b++) if (bits & (1 << b)) arches.push(archDict[b]);
        tags.push({
          tag: name, erlang: m[1], os: m[2],
          os_version: m[3], slim: !!m[4], arches: arches
        });
      }
      ALL_TAGS = tags;
    }

    let sortKeys = [
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

    const versionCols = new Set(['erlang', 'os_version']);

    function cmpField(a, b, col) {
      const va = a[col], vb = b[col];
      if (col === 'slim') return (va === vb) ? 0 : va ? 1 : -1;
      if (col === 'arches') {
        const sa = (va || []).join(','), sb = (vb || []).join(',');
        return sa < sb ? -1 : sa > sb ? 1 : 0;
      }
      if (versionCols.has(col)) return cmpVersion(va, vb);
      return va < vb ? -1 : va > vb ? 1 : 0;
    }

    function matchArch(arches, filter) {
      arches = arches || [];
      const amd64 = arches.includes('amd64'), arm64 = arches.includes('arm64');
      if (filter === 'multi') return amd64 && arm64;
      if (filter === 'amd64-only') return amd64 && !arm64;
      if (filter === 'arm64-only') return arm64 && !amd64;
      return true;
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
        const arrow = th.querySelector('.sort-arrow');
        if (arrow) arrow.textContent = '';
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
        sortKeys[0].dir = sortKeys[0].dir === 'asc' ? 'desc' : 'asc';
      } else {
        if (existing > 0) sortKeys.splice(existing, 1);
        sortKeys.unshift({col, dir: 'desc'});
      }
      updateSortUI();
      applyFilters();
    }

    function applyFilters() {
      const erlang = document.getElementById('filter-erlang').value;
      const os = document.getElementById('filter-os').value;
      const slim = document.getElementById('filter-slim').value;
      const arch = document.getElementById('filter-arch').value;

      let filtered = ALL_TAGS.filter(t => {
        if (erlang && t.erlang !== erlang) return false;
        if (os && t.os !== os) return false;
        if (slim !== '' && String(t.slim) !== slim) return false;
        if (arch && !matchArch(t.arches, arch)) return false;
        return true;
      });

      filtered = sortData(filtered);

      const tbody = document.getElementById('tag-body');
      tbody.innerHTML = filtered.slice(0, 500).map(t =>
        `<tr>
          <td>${t.tag}</td>
          <td>${t.erlang}</td>
          <td>${t.os}</td>
          <td>${t.os_version}</td>
          <td>${t.slim ? 'Yes' : ''}</td>
          <td>${(t.arches || []).join(', ')}</td>
        </tr>`
      ).join('');

      const countEl = document.getElementById('count');
      countEl.textContent = filtered.length > 500
        ? `${filtered.length} (showing first 500)`
        : filtered.length;
    }

    function copyTag(el) {
      const text = el.querySelector('code').textContent;
      navigator.clipboard.writeText('hexpm/erlang:' + text).then(() => {
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
    document.getElementById('count').textContent = 'loading…';
    loadData()
      .then(applyFilters)
      .catch(() => {
        document.getElementById('count').textContent = 'failed to load tag data';
      });
    """
  end
end
