// ====================================================================
// LOOK SYSTEM WEB DASHBOARD: Interactive Controller
// ====================================================================

const API_BASE = 'http://localhost:4000/api/v1';

// Initial state
const state = {
  currentTab: 'overview',
  timeRange: 'today',
  isMonitoring: true,
  consentGranted: true,
  user: {
    fullName: 'Jane Doe',
    email: 'jane.doe@looksystem.com',
    role: 'Organization Admin',
    organization: 'Look Enterprise Corp'
  },
  metrics: {
    totalDurationSeconds: 20520, // 5h 42m
    totalIdleSeconds: 2880,      // 48m
    productivityScore: 88,
    activeDevices: 1
  },
  categories: [
    { category: 'Development', duration: 11400, percent: 55, color: 'fill-purple' },
    { category: 'Communication', duration: 4200, percent: 20, color: 'fill-teal' },
    { category: 'Browsing', duration: 3120, percent: 15, color: 'fill-blue' },
    { category: 'Productivity', duration: 1800, percent: 10, color: 'fill-orange' }
  ],
  topApps: [
    { name: 'Visual Studio Code', category: 'Development', duration: '3h 10m', rawSecs: 11400 },
    { name: 'Slack', category: 'Communication', duration: '1h 10m', rawSecs: 4200 },
    { name: 'Google Chrome', category: 'Browsing', duration: '52m', rawSecs: 3120 },
    { name: 'Notion', category: 'Productivity', duration: '30m', rawSecs: 1800 }
  ],
  activityMatrix: [
    { app: 'Visual Studio Code', category: 'Development', title: 'look_system_core.dart — KeyFlow project', active: '3h 10m', idle: '12m', time: 'Just now' },
    { app: 'Slack', category: 'Communication', title: 'Discussions in #engineering-team', active: '1h 10m', idle: '18m', time: '14m ago' },
    { app: 'Google Chrome', category: 'Browsing', title: 'https://developer.mozilla.org/en-US/docs/Web', active: '52m', idle: '8m', time: '42m ago' },
    { app: 'Notion', category: 'Productivity', title: 'Look System Q3 Product Requirements & Architecture', active: '30m', idle: '10m', time: '1h ago' }
  ],
  auditLogs: [
    { time: 'Today, 09:15 AM', action: 'LOGIN_SUCCESS', resource: 'Auth', actor: 'jane.doe@looksystem.com', ip: '192.168.1.104' },
    { time: 'Today, 09:16 AM', action: 'DEVICE_AUTHORIZED', resource: 'Workstation', actor: 'jane.doe@looksystem.com', ip: '192.168.1.104' },
    { time: 'Yesterday, 04:30 PM', action: 'RETENTION_POLICY_SAVED', resource: 'Policy', actor: 'admin@looksystem.com', ip: '192.168.1.1' }
  ]
};

document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  initControls();
  renderDashboard();
});

function initNavigation() {
  const navButtons = document.querySelectorAll('.nav-item');
  navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const tabName = btn.dataset.tab;
      switchTab(tabName);
    });
  });

  const filterButtons = document.querySelectorAll('.filter-btn');
  filterButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      filterButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.timeRange = btn.dataset.range;
      renderDashboard();
    });
  });
}

function switchTab(tabName) {
  state.currentTab = tabName;

  document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
  const activeBtn = document.querySelector(`.nav-item[data-tab="${tabName}"]`);
  if (activeBtn) activeBtn.classList.add('active');

  document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
  const activeSection = document.getElementById(`tab-${tabName}`);
  if (activeSection) activeSection.classList.add('active');

  const titles = {
    overview: 'Executive Overview',
    timeline: 'Timeline & Sessions',
    apps: 'App Usage Breakdown',
    admin: 'Admin & Organization Controls',
    privacy: 'Privacy & Compliance Center'
  };
  document.getElementById('page-title').textContent = titles[tabName] || 'Dashboard';
}

function initControls() {
  // Quick Pause Button
  const pauseBtn = document.getElementById('btn-quick-pause');
  pauseBtn.addEventListener('click', () => {
    state.isMonitoring = !state.isMonitoring;
    const pill = document.getElementById('global-status-pill');
    if (state.isMonitoring) {
      pill.className = 'monitoring-pill active';
      pill.querySelector('.status-label').textContent = 'Monitoring: ACTIVE';
      pauseBtn.textContent = 'Pause 15m';
    } else {
      pill.className = 'monitoring-pill paused';
      pill.querySelector('.status-label').textContent = 'Monitoring: PAUSED';
      pauseBtn.textContent = 'Resume Monitoring';
    }
  });

  // Consent toggle
  const consentBtn = document.getElementById('btn-toggle-consent');
  const consentBadge = document.getElementById('consent-badge');
  consentBtn.addEventListener('click', () => {
    state.consentGranted = !state.consentGranted;
    if (state.consentGranted) {
      consentBadge.textContent = 'Consent Granted';
      consentBadge.className = 'badge status-granted';
      consentBtn.textContent = 'Revoke Consent';
    } else {
      consentBadge.textContent = 'Consent Revoked';
      consentBadge.className = 'badge';
      consentBtn.textContent = 'Grant Consent';
      state.isMonitoring = false;
      document.getElementById('global-status-pill').className = 'monitoring-pill paused';
      document.getElementById('global-status-pill').querySelector('.status-label').textContent = 'Monitoring: STOPPED';
    }
  });

  // DSAR Export
  document.getElementById('btn-export-data').addEventListener('click', downloadExportData);
  document.getElementById('btn-dsar-export').addEventListener('click', downloadExportData);

  // DSAR Delete
  document.getElementById('btn-dsar-delete').addEventListener('click', () => {
    if (confirm('Are you sure you want to permanently erase all your historical activity records? This action is irreversible.')) {
      state.activityMatrix = [];
      state.metrics.totalDurationSeconds = 0;
      state.metrics.totalIdleSeconds = 0;
      state.metrics.productivityScore = 100;
      renderDashboard();
      alert('Your activity records have been permanently erased from the database.');
    }
  });

  // Retention policy form
  document.getElementById('form-retention').addEventListener('submit', (e) => {
    e.preventDefault();
    const days = document.getElementById('retention-days').value;
    alert(`Retention policy updated: activity records older than ${days} days will be automatically purged.`);
  });

  document.getElementById('btn-purge-now').addEventListener('click', () => {
    alert('Cryptographic retention purge job triggered successfully. Expired records removed.');
  });
}

function downloadExportData() {
  const exportPayload = {
    exportDate: new Date().toISOString(),
    user: state.user,
    consentStatus: state.consentGranted ? 'granted' : 'revoked',
    telemetryMetrics: state.metrics,
    activityEntries: state.activityMatrix
  };

  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(exportPayload, null, 2));
  const downloadAnchor = document.createElement('a');
  downloadAnchor.setAttribute("href", dataStr);
  downloadAnchor.setAttribute("download", `look_system_telemetry_export_${Date.now()}.json`);
  document.body.appendChild(downloadAnchor);
  downloadAnchor.click();
  downloadAnchor.remove();
}

function renderDashboard() {
  // 1. Render Category Distribution
  const catContainer = document.getElementById('category-bars-container');
  if (catContainer) {
    catContainer.innerHTML = state.categories.map(c => `
      <div class="category-bar-item">
        <div class="category-meta">
          <span>${c.category}</span>
          <span style="font-weight: 600;">${c.percent}%</span>
        </div>
        <div class="bar-track">
          <div class="bar-fill ${c.color}" style="width: ${c.percent}%;"></div>
        </div>
      </div>
    `).join('');
  }

  // 2. Render Top Applications
  const topContainer = document.getElementById('top-apps-container');
  if (topContainer) {
    topContainer.innerHTML = state.topApps.map(app => `
      <div class="top-app-item">
        <div class="app-badge-icon">${app.name.substring(0, 2).toUpperCase()}</div>
        <div class="app-meta">
          <span class="app-name">${app.name}</span>
          <span class="app-cat">${app.category}</span>
        </div>
        <div class="app-time">${app.duration}</div>
      </div>
    `).join('');
  }

  // 3. Render Activity Matrix Table
  const matrixBody = document.getElementById('app-matrix-body');
  if (matrixBody) {
    if (state.activityMatrix.length === 0) {
      matrixBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 32px;">No activity records found.</td></tr>`;
    } else {
      matrixBody.innerHTML = state.activityMatrix.map(row => `
        <tr>
          <td style="font-weight: 600;">${row.app}</td>
          <td><span class="badge">${row.category}</span></td>
          <td style="color: var(--text-secondary); font-family: 'JetBrains Mono', monospace; font-size: 12px;">${row.title}</td>
          <td style="color: var(--accent-teal); font-weight: 600;">${row.active}</td>
          <td style="color: var(--text-muted);">${row.idle}</td>
          <td style="color: var(--text-muted);">${row.time}</td>
        </tr>
      `).join('');
    }
  }

  // 4. Render Audit Logs
  const auditBody = document.getElementById('audit-logs-body');
  if (auditBody) {
    auditBody.innerHTML = state.auditLogs.map(log => `
      <tr>
        <td style="color: var(--text-muted);">${log.time}</td>
        <td><strong style="color: var(--accent-purple);">${log.action}</strong></td>
        <td>${log.resource}</td>
        <td>${log.actor}</td>
        <td style="font-family: 'JetBrains Mono', monospace; font-size: 11px;">${log.ip}</td>
      </tr>
    `).join('');
  }
}
