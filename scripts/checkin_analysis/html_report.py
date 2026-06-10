"""
Generate HTML visualization report for check-in analysis.
"""

import json
from datetime import datetime


def generate_html_report(data: dict, analysis: dict, athletes_by_id: dict, output_path: str, preprocess_info: dict = None):
    """Generate an HTML report with charts and tables."""
    
    # Prepare chart data
    chart_data = _prepare_chart_data(analysis)
    
    # Build roster by age data
    roster_by_age = _build_roster_by_age(analysis, athletes_by_id)
    
    # Generate HTML sections
    html_parts = [
        _html_head(),
        _html_header(data, preprocess_info),
        _html_summary(analysis, data, preprocess_info),
        _html_charts(),
        _html_roster_by_age(roster_by_age),
        _html_multi_device(analysis["multi_device"]),
        _html_scripts(chart_data),
        _html_footer(),
    ]
    
    html = "\n".join(html_parts)
    
    with open(output_path, "w") as fp:
        fp.write(html)
    
    print(f"   Written HTML report to {output_path}")


def _prepare_chart_data(analysis: dict) -> dict:
    """Prepare data for Chart.js visualizations."""
    # Age chart: stacked bar with checked-in and not-checked-in
    age_labels = [str(a) for a in analysis["age_totals"].keys()]
    age_checked = [analysis["age_counts"].get(a, 0) for a in analysis["age_totals"].keys()]
    age_not_checked = [analysis["age_totals"][a] - analysis["age_counts"].get(a, 0) for a in analysis["age_totals"].keys()]
    
    # Gender+Age chart: grouped bar for Male/Female by age
    all_ages = sorted(analysis["age_totals"].keys())
    male_checked = [analysis["gender_age_counts"]["Male"].get(a, 0) for a in all_ages]
    female_checked = [analysis["gender_age_counts"]["Female"].get(a, 0) for a in all_ages]
    male_not = [analysis["gender_age_totals"]["Male"].get(a, 0) - analysis["gender_age_counts"]["Male"].get(a, 0) for a in all_ages]
    female_not = [analysis["gender_age_totals"]["Female"].get(a, 0) - analysis["gender_age_counts"]["Female"].get(a, 0) for a in all_ages]
    
    return {
        "minute_labels": list(analysis["minute_counts"].keys()),
        "minute_values": list(analysis["minute_counts"].values()),
        "age_labels": age_labels,
        "age_checked": age_checked,
        "age_not_checked": age_not_checked,
        "gender_labels": list(analysis["gender_counts"].keys()),
        "gender_values": list(analysis["gender_counts"].values()),
        "gender_age_labels": [str(a) for a in all_ages],
        "male_checked": male_checked,
        "female_checked": female_checked,
        "male_not": male_not,
        "female_not": female_not,
    }


def _build_roster_by_age(analysis: dict, athletes_by_id: dict) -> dict:
    """Build roster data grouped by age with checked/missing bib numbers."""
    # Group all athletes by age
    by_age = {}
    for pid, athlete in athletes_by_id.items():
        age = athlete.get("age")
        if age is None:
            continue
        if age not in by_age:
            by_age[age] = {"checked": [], "missing": []}
        
        if pid in analysis["not_checked_in_ids"]:
            by_age[age]["missing"].append(pid)
        else:
            by_age[age]["checked"].append(pid)
    
    # Sort bib numbers within each group
    for age in by_age:
        by_age[age]["checked"] = sorted(by_age[age]["checked"], key=int)
        by_age[age]["missing"] = sorted(by_age[age]["missing"], key=int)
    
    return dict(sorted(by_age.items()))


def _html_head() -> str:
    return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EmP Check-In Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {
            --color-checked: #34c759;    /* Green - positive/checked in */
            --color-missing: #8e8e93;    /* Gray - neutral/missing */
            --color-boys: #007aff;       /* Blue - boys */
            --color-girls: #af52de;      /* Purple - girls */
            --color-activity: #5ac8fa;   /* Teal - activity/heartbeat */
            --color-text: #1d1d1f;
            --color-muted: #86868b;
            --color-border: #e5e5ea;
            --color-bg: #f5f5f7;
        }
        * { box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
               margin: 0; padding: 20px; background: var(--color-bg); color: var(--color-text); }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 { color: var(--color-text); margin-bottom: 8px; }
        h2 { color: #424245; margin-top: 32px; margin-bottom: 16px; 
             border-bottom: 2px solid var(--color-checked); padding-bottom: 8px; }
        .subtitle { color: var(--color-muted); margin-bottom: 12px; font-size: 14px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                      gap: 16px; margin-bottom: 24px; }
        .stat-card { background: white; border-radius: 12px; padding: 20px;
                     box-shadow: 0 2px 8px rgba(0,0,0,0.08); text-align: center; }
        .stat-value { font-size: 42px; font-weight: 700; color: var(--color-text); }
        .stat-value.checked { color: var(--color-checked); }
        .stat-value.missing { color: var(--color-missing); }
        .stat-label { color: var(--color-muted); font-size: 13px; margin-top: 4px; }
        .stat-highlight { background: linear-gradient(135deg, #34c759 0%, #30d158 100%); }
        .stat-highlight .stat-value { color: white; }
        .stat-highlight .stat-label { color: rgba(255,255,255,0.9); }
        .chart-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
                      gap: 24px; margin-bottom: 32px; }
        .chart-card { background: white; border-radius: 12px; padding: 20px;
                      box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .chart-title { font-weight: 600; margin-bottom: 4px; color: var(--color-text); }
        .chart-subtitle { font-size: 12px; color: var(--color-muted); margin-bottom: 16px; }
        table { width: 100%; border-collapse: collapse; background: white; border-radius: 12px;
                overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid var(--color-border); }
        th { background: var(--color-bg); font-weight: 600; color: #424245; }
        tr:hover { background: var(--color-bg); }
        tr.highlight { background: #fff3cd; }
        .badge { display: inline-block; padding: 4px 8px; border-radius: 6px;
                 font-size: 12px; font-weight: 600; }
        .badge-warning { background: #fff3cd; color: #856404; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        .collapsible { cursor: pointer; user-select: none; }
        .collapsible::before { content: "▼ "; font-size: 12px; }
        .collapsible.collapsed::before { content: "▶ "; }
        .collapse-content { display: block; }
        .collapse-content.hidden { display: none; }
        .search-box { width: 100%; padding: 12px 16px; border: 1px solid var(--color-border);
                      border-radius: 8px; margin-bottom: 16px; font-size: 16px; }
        .section-note { background: #f0f0f5; border-radius: 8px; padding: 12px 16px;
                        margin-bottom: 16px; font-size: 13px; color: var(--color-muted); }
        .legend-hint { display: inline-flex; align-items: center; gap: 16px; 
                       font-size: 12px; color: var(--color-muted); margin-bottom: 12px; }
        .legend-dot { width: 12px; height: 12px; border-radius: 3px; display: inline-block; margin-right: 4px; }
        /* Age tabs and roster */
        .age-tabs { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 16px; }
        .age-tab { padding: 8px 16px; border: 1px solid var(--color-border); border-radius: 20px;
                   background: white; cursor: pointer; font-size: 13px; transition: all 0.2s; }
        .age-tab:hover { border-color: var(--color-checked); }
        .age-tab.active { background: var(--color-checked); color: white; border-color: var(--color-checked); }
        .age-panel { display: none; background: white; border-radius: 12px; padding: 20px;
                     box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .age-panel.active { display: block; }
        .age-summary { font-size: 14px; color: var(--color-muted); margin-bottom: 16px; }
        .bib-section { margin-bottom: 16px; }
        .bib-label { font-size: 13px; font-weight: 600; margin-bottom: 8px; }
        .bib-list { display: flex; flex-wrap: wrap; gap: 6px; }
        .bib { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-family: monospace; }
        .bib-checked { background: #e8f5e9; color: #2e7d32; }
        .bib-missing { background: #fafafa; color: #757575; }
        .bib-empty { color: var(--color-muted); font-style: italic; }
        .nav-links { margin-bottom: 16px; display: flex; gap: 16px; }
        .nav-links a { color: #007aff; text-decoration: none; font-size: 14px; }
        .nav-links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
<div class="container">'''


def _html_header(data: dict, preprocess_info: dict = None) -> str:
    now = datetime.now().strftime("%Y年%m月%d日 %H:%M")
    event_start = preprocess_info.get("event_start_pst", "N/A") if preprocess_info else "N/A"
    unique_devices = len(set(f["device_id"] for f in data["files"]))
    return f'''
    <nav class="nav-links">
        <a href="./">← 返回 Home</a>
    </nav>
    <h1>🏃 EmP 签到报告 Check-In Report</h1>
    <p class="subtitle">生成时间 {now} · {unique_devices} 台设备 (iPad) · 比赛开始 {event_start}</p>'''


def _html_summary(analysis: dict, data: dict, preprocess_info: dict = None) -> str:
    total = analysis["total_athletes"]
    checked_in = analysis["unique_checked_in"]
    not_checked = analysis["not_checked_in_count"]
    rate = (checked_in / total * 100) if total > 0 else 0
    return f'''
    <h2>📊 数据总览 At a Glance</h2>
    <div class="stats-grid">
        <div class="stat-card stat-highlight">
            <div class="stat-value">{rate:.0f}%</div>
            <div class="stat-label">签到率 Check-In Rate</div>
        </div>
        <div class="stat-card">
            <div class="stat-value checked">{checked_in}</div>
            <div class="stat-label">已签到 Checked In</div>
        </div>
        <div class="stat-card">
            <div class="stat-value missing">{not_checked}</div>
            <div class="stat-label">未签到 Missing</div>
        </div>
        <div class="stat-card">
            <div class="stat-value">{total}</div>
            <div class="stat-label">运动员总数 Total</div>
        </div>
    </div>'''


def _html_duplicate_exports(data: dict) -> str:
    if not data["duplicate_exports"]:
        return ""
    items = "\n".join(
        f'        <li>Device {d["device"]}: {d["export1"]} and {d["export2"]} ({d["event_count"]} events)</li>'
        for d in data["duplicate_exports"]
    )
    return f'''
    <div class="warning-box">
        <strong>⚠️ Duplicate Exports Detected:</strong>
        <ul>{items}</ul>
    </div>'''


def _html_multi_device(rows: list) -> str:
    if not rows:
        return ""
    
    table_rows = []
    for r in rows:
        badge = "badge-danger" if r["checkInCount"] > 3 else "badge-warning"
        ts = ", ".join(r["timestamps"][:3]) + ("..." if len(r["timestamps"]) > 3 else "")
        table_rows.append(f'''            <tr class="highlight">
                <td><strong>#{r["bibNumber"]}</strong></td>
                <td>{r.get("age", "?")}</td>
                <td><span class="badge {badge}">{r["checkInCount"]}x</span></td>
                <td>{", ".join(r["devices"])}</td>
                <td style="font-size: 12px;">{ts}</td>
            </tr>''')
    
    return f'''
    <h2>⚠️ 多设备签到 Multi-Device Check-Ins ({len(rows)})</h2>
    <p style="color: #86868b;">这些运动员在多个设备上签到</p>
    <table>
        <thead>
            <tr><th>号码 Bib</th><th>年龄 Age</th><th>次数</th><th>设备 Devices</th><th>时间 Time (PST)</th></tr>
        </thead>
        <tbody>
{chr(10).join(table_rows)}
        </tbody>
    </table>'''


def _html_charts() -> str:
    return '''
    <h2>📈 签到动态 Check-In Activity</h2>
    <div class="chart-grid">
        <div class="chart-card" style="grid-column: span 2;">
            <div class="chart-title">💓 签到心跳图 Live Check-In Flow</div>
            <div class="chart-subtitle">每分钟签到人数 - 展示签到效率</div>
            <canvas id="heartbeatChart"></canvas>
        </div>
        <div class="chart-card">
            <div class="chart-title">按年龄 By Age</div>
            <div class="chart-subtitle">绿色=已签到，灰色=未签到</div>
            <canvas id="ageChart"></canvas>
        </div>
        <div class="chart-card">
            <div class="chart-title">按性别 By Gender</div>
            <div class="chart-subtitle">已签到运动员分布</div>
            <canvas id="genderChart"></canvas>
        </div>
        <div class="chart-card" style="grid-column: span 2;">
            <div class="chart-title">性别 × 年龄 Gender by Age</div>
            <div class="chart-subtitle">对比各年龄段男女签到情况</div>
            <canvas id="genderAgeChart"></canvas>
        </div>
    </div>'''


def _html_operators(analysis: dict) -> str:
    rows = "\n".join(
        f'            <tr><td>{i}</td><td>{op}</td><td>{cnt}</td></tr>'
        for i, (op, cnt) in enumerate(analysis["operator_counts"].items(), 1)
        if i <= 20
    )
    return f'''
    <h2>🏆 Top Operators</h2>
    <table>
        <thead><tr><th>Rank</th><th>Operator</th><th>Check-Ins</th></tr></thead>
        <tbody>
{rows}
        </tbody>
    </table>'''


def _html_roster_by_age(roster_by_age: dict) -> str:
    """Generate HTML for roster by age with expandable sections."""
    # Calculate totals for "All" tab
    total_checked = sum(len(data["checked"]) for data in roster_by_age.values())
    total_all = sum(len(data["checked"]) + len(data["missing"]) for data in roster_by_age.values())
    total_rate = (total_checked / total_all * 100) if total_all > 0 else 0
    
    # Build age tabs
    tabs = []
    panels = []
    
    for age, data in roster_by_age.items():
        checked_count = len(data["checked"])
        missing_count = len(data["missing"])
        total = checked_count + missing_count
        rate = (checked_count / total * 100) if total > 0 else 0
        
        # Tab button
        tabs.append(f'<button class="age-tab" onclick="showAge({age})" id="tab-{age}">{age}岁 ({checked_count}/{total}) {rate:.0f}%</button>')
        
        # Panel content
        checked_bibs = " ".join(f'<span class="bib bib-checked">#{b}</span>' for b in data["checked"])
        missing_bibs = " ".join(f'<span class="bib bib-missing">#{b}</span>' for b in data["missing"])
        
        panels.append(f'''
        <div class="age-panel" id="panel-{age}">
            <div class="age-summary">
                <strong>{age}岁 Age {age}</strong> · {checked_count}/{total} 已签到 · {rate:.0f}%
            </div>
            <div class="bib-section">
                <div class="bib-label">✅ 已签到 Checked In ({checked_count})</div>
                <div class="bib-list">{checked_bibs if checked_bibs else '<span class="bib-empty">无 None</span>'}</div>
            </div>
            <div class="bib-section">
                <div class="bib-label">❌ 未签到 Missing ({missing_count})</div>
                <div class="bib-list">{missing_bibs if missing_bibs else '<span class="bib-empty">无 None</span>'}</div>
            </div>
        </div>''')
    
    return f'''
    <h2>📋 按年龄查看 Roster by Age</h2>
    <div class="age-tabs">
        <button class="age-tab active" onclick="showAge('all')" id="tab-all">全部 All ({total_checked}/{total_all}) {total_rate:.0f}%</button>
        {chr(10).join(tabs)}
    </div>
    <div id="panel-all" class="age-panel active">
        <div class="age-summary">点击上方年龄标签查看详情 · Click an age tab above to see details</div>
    </div>
    {chr(10).join(panels)}'''


def _html_export_files(data: dict) -> str:
    rows = "\n".join(
        f'            <tr><td>{f["filename"]}</td><td>{f["device_id"]}</td><td>{f["export_time"]}</td><td>{f["event_count"]}</td></tr>'
        for f in data["files"]
    )
    return f'''
    <h2>📱 Export Files</h2>
    <table>
        <thead><tr><th>File</th><th>Device</th><th>Export Time</th><th>Events</th></tr></thead>
        <tbody>
{rows}
        </tbody>
    </table>'''


def _html_scripts(chart_data: dict) -> str:
    return f'''
</div>
<script>
    // Color palette
    const colors = {{
        checked: '#34c759',      // Green
        missing: '#c7c7cc',      // Light gray
        boys: '#007aff',         // Blue
        girls: '#af52de',        // Purple
        activity: '#5ac8fa',     // Teal
        boysMissing: '#b3d7ff',  // Light blue
        girlsMissing: '#e4c8f2'  // Light purple
    }};

    new Chart(document.getElementById('heartbeatChart'), {{
        type: 'bar',
        data: {{
            labels: {json.dumps(chart_data["minute_labels"])},
            datasets: [{{ label: '签到 Check-ins', data: {json.dumps(chart_data["minute_values"])},
                backgroundColor: colors.activity, borderRadius: 2 }}]
        }},
        options: {{
            responsive: true,
            plugins: {{ legend: {{ display: false }} }},
            scales: {{
                x: {{ title: {{ display: true, text: '时间 Time (PST)' }}, ticks: {{ maxRotation: 90, minRotation: 45 }} }},
                y: {{ beginAtZero: true, title: {{ display: true, text: '每分钟人数 Athletes/min' }} }}
            }}
        }}
    }});

    new Chart(document.getElementById('ageChart'), {{
        type: 'bar',
        data: {{
            labels: {json.dumps(chart_data["age_labels"])},
            datasets: [
                {{ label: '已签到 Checked In', data: {json.dumps(chart_data["age_checked"])}, backgroundColor: colors.checked }},
                {{ label: '未签到 Missing', data: {json.dumps(chart_data["age_not_checked"])}, backgroundColor: colors.missing }}
            ]
        }},
        options: {{
            responsive: true,
            plugins: {{ legend: {{ display: true, position: 'top' }} }},
            scales: {{ x: {{ stacked: true }}, y: {{ stacked: true, beginAtZero: true }} }}
        }}
    }});

    new Chart(document.getElementById('genderChart'), {{
        type: 'doughnut',
        data: {{ labels: ['男 Boys', '女 Girls'],
            datasets: [{{ data: {json.dumps(chart_data["gender_values"])}, backgroundColor: [colors.boys, colors.girls, '#8e8e93'] }}] }},
        options: {{ responsive: true }}
    }});

    new Chart(document.getElementById('genderAgeChart'), {{
        type: 'bar',
        data: {{
            labels: {json.dumps(chart_data["gender_age_labels"])},
            datasets: [
                {{ label: '男 ✓', data: {json.dumps(chart_data["male_checked"])}, backgroundColor: colors.boys, stack: 'boys' }},
                {{ label: '男 未签', data: {json.dumps(chart_data["male_not"])}, backgroundColor: colors.boysMissing, stack: 'boys' }},
                {{ label: '女 ✓', data: {json.dumps(chart_data["female_checked"])}, backgroundColor: colors.girls, stack: 'girls' }},
                {{ label: '女 未签', data: {json.dumps(chart_data["female_not"])}, backgroundColor: colors.girlsMissing, stack: 'girls' }}
            ]
        }},
        options: {{
            responsive: true,
            plugins: {{ legend: {{ display: true, position: 'top' }} }},
            scales: {{ x: {{ stacked: true }}, y: {{ stacked: true, beginAtZero: true }} }}
        }}
    }});

    function toggleSection(id) {{
        const el = document.getElementById(id);
        el.classList.toggle('hidden');
        el.previousElementSibling.classList.toggle('collapsed');
    }}

    function filterTable(tableId, query) {{
        const rows = document.getElementById(tableId).querySelectorAll('tbody tr');
        const q = query.toLowerCase();
        rows.forEach(r => r.style.display = r.textContent.toLowerCase().includes(q) ? '' : 'none');
    }}

    function showAge(age) {{
        // Hide all panels and deactivate all tabs
        document.querySelectorAll('.age-panel').forEach(p => p.classList.remove('active'));
        document.querySelectorAll('.age-tab').forEach(t => t.classList.remove('active'));
        // Show selected panel and activate tab
        document.getElementById('panel-' + age).classList.add('active');
        document.getElementById('tab-' + age).classList.add('active');
    }}
</script>'''


def _html_footer() -> str:
    return '''
</body>
</html>'''
