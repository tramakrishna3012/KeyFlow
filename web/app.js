// Look System Web Application & Dashboard Controller

const API_BASE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  ? 'http://localhost:3000/api/v1'
  : '/api/v1';

let authToken = localStorage.getItem('look_jwt_token') || '';
let currentUser = null;
let currentSessionId = null;

// Initialize on DOM Load
document.addEventListener('DOMContentLoaded', async () => {
  setupNavigation();
  setupSessionControls();
  setupSearch();
  setupExclusions();
  setupDsar();

  await autoLoginOrMock();
  await loadOverviewData();
  await loadSessionsList();
  await loadExclusions();
});

// Auto-Login or Test Account Registration
async function autoLoginOrMock() {
  if (!authToken) {
    try {
      const email = `owner_${Date.now()}@looksystem.com`;
      const res = await fetch(`${API_BASE}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          password: 'LookOwnerPassword123!',
          fullName: 'Authorized Workstation Owner',
          role: 'admin',
          organizationName: 'Look System Organization'
        })
      });
      const data = await res.json();
      if (data.token) {
        authToken = data.token;
        localStorage.setItem('look_jwt_token', authToken);
        currentUser = data.user;
        updateUserUI();
      }
    } catch {
      console.warn('API offline - falling back to demo mode.');
    }
  } else {
    try {
      const res = await fetch(`${API_BASE}/auth/me`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      const data = await res.json();
      if (data.user) {
        currentUser = data.user;
        updateUserUI();
      }
    } catch {
      console.warn('Session verification failed.');
    }
  }
}

function updateUserUI() {
  if (currentUser) {
    document.getElementById('user-name').textContent = currentUser.full_name || 'Authorized Owner';
    document.getElementById('user-role').textContent = currentUser.role === 'admin' ? 'Administrator' : 'Team Member';
    const initials = (currentUser.full_name || 'AO').split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
    document.getElementById('user-avatar').textContent = initials;
  }
}

// Navigation Tabs
function setupNavigation() {
  const navButtons = document.querySelectorAll('.nav-item');
  navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      navButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const tabId = btn.getAttribute('data-tab');
      document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
      const activeTab = document.getElementById(`tab-${tabId}`);
      if (activeTab) activeTab.classList.add('active');

      const titles = {
        overview: 'Executive Overview',
        sessions: 'Monitoring Session Explorer',
        search: 'Multi-Criteria Search & Filtering',
        apps: 'Application Telemetry Matrix',
        admin: 'Admin & Organization Controls',
        privacy: 'Privacy & Exclusions'
      };
      document.getElementById('page-title').textContent = titles[tabId] || 'Look System';
    });
  });
}

// Session Controls
function setupSessionControls() {
  document.getElementById('btn-start-session-header')?.addEventListener('click', async () => {
    try {
      const res = await fetch(`${API_BASE}/activity/sessions/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`
        },
        body: JSON.stringify({ deviceName: 'Web Console Workstation' })
      });
      const data = await res.json();
      if (data.sessionId) {
        currentSessionId = data.sessionId;
        alert(`Session started: ${data.sessionId}`);
        loadSessionsList();
      }
    } catch (e) {
      alert(`Error starting session: ${e.message}`);
    }
  });

  document.getElementById('btn-pause-session-header')?.addEventListener('click', async () => {
    if (!currentSessionId) return alert('No active session.');
    await fetch(`${API_BASE}/activity/sessions/pause`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`
      },
      body: JSON.stringify({ sessionId: currentSessionId })
    });
    alert('Session paused.');
    loadSessionsList();
  });

  document.getElementById('btn-stop-session-header')?.addEventListener('click', async () => {
    if (!currentSessionId) return alert('No active session.');
    await fetch(`${API_BASE}/activity/sessions/stop`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`
      },
      body: JSON.stringify({ sessionId: currentSessionId })
    });
    alert('Session completed.');
    currentSessionId = null;
    loadSessionsList();
  });
}

// Overview Data Loading
async function loadOverviewData() {
  try {
    const res = await fetch(`${API_BASE}/activity/summary`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();

    if (data.metrics) {
      const activeMin = Math.round(data.metrics.totalActiveSeconds / 60);
      const hours = Math.floor(activeMin / 60);
      const mins = activeMin % 60;
      document.getElementById('val-active-time').textContent = `${hours}h ${mins}m`;
      document.getElementById('val-total-activity').textContent = data.metrics.logCount || '0';
      document.getElementById('val-focus-score').textContent = `${data.metrics.productivityScore || 88}%`;
    }

    // Categories
    const catContainer = document.getElementById('category-bars-container');
    if (catContainer && data.categories) {
      catContainer.innerHTML = data.categories.map(cat => {
        const min = Math.round(cat.duration / 60);
        return `
          <div class="category-item">
            <div class="cat-info">
              <span>${cat.category}</span>
              <span>${min} min</span>
            </div>
            <div class="progress-bar-bg">
              <div class="progress-bar-fill" style="width: ${Math.min(100, Math.max(10, min * 2))}%;"></div>
            </div>
          </div>
        `;
      }).join('');
    }

    // Top Apps
    const topAppsContainer = document.getElementById('top-apps-container');
    if (topAppsContainer && data.topApps) {
      topAppsContainer.innerHTML = data.topApps.map(app => {
        const min = Math.round(app.duration / 60);
        return `
          <div class="app-row">
            <div class="app-meta">
              <div class="app-avatar">${app.appName[0].toUpperCase()}</div>
              <div>
                <strong>${app.appName}</strong>
                <div style="font-size: 11px; color: var(--text-muted);">${app.category}</div>
              </div>
            </div>
            <span>${min} min</span>
          </div>
        `;
      }).join('');
    }

    // Matrix
    const matrixBody = document.getElementById('app-matrix-body');
    if (matrixBody && data.recentLogs) {
      matrixBody.innerHTML = data.recentLogs.map(log => `
        <tr>
          <td><strong>${log.appName}</strong></td>
          <td><span class="badge">${log.category}</span></td>
          <td>${log.windowTitle}</td>
          <td>${Math.round(log.durationSeconds / 60)} min</td>
          <td>${log.idleSeconds}s</td>
          <td>${new Date(log.startedAt).toLocaleTimeString()}</td>
        </tr>
      `).join('');
    }
  } catch (err) {
    console.error('Failed to load activity summary:', err);
  }
}

// Session Explorer: List & Hierarchical Tree
async function loadSessionsList() {
  const container = document.getElementById('sessions-list-container');
  if (!container) return;

  try {
    const res = await fetch(`${API_BASE}/activity/sessions`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();
    const sessions = data.sessions || [];

    if (sessions.length === 0) {
      container.innerHTML = '<div class="text-muted text-center py-3">No sessions recorded yet.</div>';
      return;
    }

    container.innerHTML = sessions.map((s, idx) => `
      <div class="session-item ${idx === 0 ? 'selected' : ''}" data-id="${s.id}">
        <div class="session-header-line">
          <span>Session: ${new Date(s.started_at).toLocaleDateString()}</span>
          <span class="badge">${s.status}</span>
        </div>
        <div class="session-meta-line">
          Device: ${s.device_name} • ${Math.round(s.total_active_seconds / 60)} min
        </div>
      </div>
    `).join('');

    // Attach click handlers
    document.querySelectorAll('.session-item').forEach(item => {
      item.addEventListener('click', () => {
        document.querySelectorAll('.session-item').forEach(el => el.classList.remove('selected'));
        item.classList.add('selected');
        const id = item.getAttribute('data-id');
        loadSessionTree(id);
      });
    });

    if (sessions.length > 0) {
      loadSessionTree(sessions[0].id);
    }
  } catch (e) {
    console.error('Error fetching sessions:', e);
  }
}

async function loadSessionTree(sessionId) {
  const container = document.getElementById('session-apps-tree-container');
  const header = document.getElementById('session-details-header');
  if (!container) return;

  try {
    const res = await fetch(`${API_BASE}/activity/sessions/${sessionId}`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();

    if (!data.session) return;

    header.innerHTML = `
      <h4>Session: ${new Date(data.session.started_at).toLocaleString()} (${data.session.device_name})</h4>
      <p class="text-muted" style="font-size: 12px;">Status: ${data.session.status} • Total Active: ${Math.round(data.session.total_active_seconds / 60)} min • Total Apps: ${data.applications.length}</p>
    `;

    if (data.applications.length === 0) {
      container.innerHTML = '<div class="text-muted">No applications recorded under this session.</div>';
      return;
    }

    container.innerHTML = data.applications.map(app => `
      <div class="session-app-node">
        <div class="app-node-header">
          <span>${app.app_name} (${app.app_category})</span>
          <span>${Math.round(app.total_duration_seconds / 60)} min</span>
        </div>
        <div class="app-node-body">
          <div style="font-weight: 600; font-size: 12px; margin-bottom: 6px;">Activity Timeline:</div>
          ${app.activityTimeline.slice(0, 5).map(evt => `
            <div class="timeline-event-item">
              <span>•</span>
              <span>${evt.windowTitle} (${evt.durationSeconds}s) [${new Date(evt.startedAt).toLocaleTimeString()}]</span>
            </div>
          `).join('')}

          ${app.textRecords.length > 0 ? `
            <div style="font-weight: 600; font-size: 12px; margin-top: 10px;">Permitted Text History:</div>
            ${app.textRecords.map(rec => `
              <div class="text-record-box">
                <span style="color: ${rec.isExcluded ? 'var(--accent-red)' : 'var(--accent-teal)'};">
                  ${rec.isExcluded ? '[Excluded by Privacy Filter]' : '✓ Permitted:'}
                </span>
                ${rec.content}
              </div>
            `).join('')}
          ` : ''}
        </div>
      </div>
    `).join('');
  } catch (e) {
    console.error('Failed to load session tree:', e);
  }
}

// Search & Filtering
function setupSearch() {
  document.getElementById('btn-execute-search')?.addEventListener('click', async () => {
    const q = document.getElementById('search-keyword-input')?.value || '';
    const appName = document.getElementById('search-app-input')?.value || '';

    const tbody = document.getElementById('search-results-body');
    if (!tbody) return;

    try {
      const url = new URL(`${API_BASE}/activity/search`);
      if (q) url.searchParams.append('q', q);
      if (appName) url.searchParams.append('appName', appName);

      const res = await fetch(url.toString(), {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      const data = await res.json();
      const results = data.results || [];

      if (results.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No matching records found.</td></tr>';
        return;
      }

      tbody.innerHTML = results.map(r => `
        <tr>
          <td>${new Date(r.timestamp).toLocaleTimeString()}</td>
          <td>${r.deviceName}</td>
          <td><strong>${r.appName}</strong></td>
          <td>${r.windowTitle}</td>
          <td>${r.isExcluded ? '<span style="color:var(--accent-red)">[Excluded]</span>' : (r.textPreview || '—')}</td>
          <td>${r.durationSeconds}s</td>
        </tr>
      `).join('');
    } catch (e) {
      console.error('Search failed:', e);
    }
  });
}

// Privacy Exclusions
async function loadExclusions() {
  const container = document.getElementById('exclusion-chips-container');
  if (!container) return;

  try {
    const res = await fetch(`${API_BASE}/activity/privacy/exclusions`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();
    const list = data.exclusions || [];

    container.innerHTML = list.map(item => `
      <div class="chip">
        <span>${item.appName || item.fieldType}</span>
      </div>
    `).join('');
  } catch (e) {
    console.error('Failed to load exclusions:', e);
  }
}

function setupExclusions() {
  document.getElementById('btn-add-exclusion')?.addEventListener('click', async () => {
    const input = document.getElementById('input-new-exclusion');
    if (!input || !input.value.trim()) return;

    const appName = input.value.trim();
    try {
      await fetch(`${API_BASE}/activity/privacy/exclusions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`
        },
        body: JSON.stringify({ appName })
      });
      input.value = '';
      loadExclusions();
      alert(`Excluded "${appName}" from monitoring.`);
    } catch (e) {
      alert(`Failed to add exclusion: ${e.message}`);
    }
  });
}

// DSAR & Compliance
function setupDsar() {
  document.getElementById('btn-dsar-export')?.addEventListener('click', async () => {
    window.open(`${API_BASE}/compliance/export?format=json`, '_blank');
  });

  document.getElementById('btn-export-data')?.addEventListener('click', async () => {
    window.open(`${API_BASE}/compliance/export?format=csv`, '_blank');
  });

  document.getElementById('btn-dsar-delete')?.addEventListener('click', async () => {
    if (!confirm('Are you sure you want to permanently erase all activity records? This action cannot be undone.')) return;

    try {
      const res = await fetch(`${API_BASE}/compliance/delete-my-data`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${authToken}` }
      });
      const data = await res.json();
      alert(data.message || 'Records erased.');
      loadOverviewData();
      loadSessionsList();
    } catch (e) {
      alert(`Failed to delete data: ${e.message}`);
    }
  });
}
