// ==========================================================================
// KeyFlow & Look System — Web Application & Marketing Controller (Light Theme)
// ==========================================================================

const API_BASE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  ? 'http://localhost:4000/api/v1'
  : 'https://keyflow-dnsd.onrender.com/api/v1';

// Safe Storage Helper (prevents SecurityError if third-party cookies/storage are blocked)
const memoryStore = {};
function safeGetItem(key) {
  try {
    return window.localStorage ? window.localStorage.getItem(key) || '' : (memoryStore[key] || '');
  } catch {
    return memoryStore[key] || '';
  }
}

function safeSetItem(key, value) {
  try {
    if (window.localStorage) window.localStorage.setItem(key, value);
  } catch {
    memoryStore[key] = value;
  }
}

function safeRemoveItem(key) {
  try {
    if (window.localStorage) window.localStorage.removeItem(key);
  } catch {
    delete memoryStore[key];
  }
}

let authToken = safeGetItem('look_jwt_token');
let currentUser = null;
let currentSessionId = null;

// Initialize on DOM Load
document.addEventListener('DOMContentLoaded', async () => {
  setupMarketingSite();
  setupDownloadsGrid();
  setupNavigation();
  setupSessionControls();
  setupTypingHistory();
  setupSearch();
  setupExclusions();
  setupAdminControls();
  setupAuthModal();

  await verifyAuthOrPrompt();
  if (currentUser) {
    await refreshAllDashboardData();
  }
});

// ==========================================================================
// Toast & Alert Notification System (Replaces browser pop-up alerts)
// ==========================================================================

function showToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const icons = {
    success: '✅',
    error: '❌',
    info: 'ℹ️'
  };

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `
    <span>${icons[type] || '🔔'}</span>
    <div style="flex: 1; font-weight: 500;">${message}</div>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(20px) scale(0.95)';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

function showAuthAlert(message, type = 'error') {
  const alertBox = document.getElementById('auth-alert');
  if (!alertBox) return;

  const icons = {
    error: '⚠️',
    success: '✅',
    info: '💡'
  };

  alertBox.className = `alert-box ${type}`;
  alertBox.innerHTML = `<span>${icons[type] || '⚠️'}</span><span>${message}</span>`;
  alertBox.style.display = 'flex';
}

function hideAuthAlert() {
  const alertBox = document.getElementById('auth-alert');
  if (alertBox) alertBox.style.display = 'none';
}

// ==========================================================================
// Marketing Site Interactive Features
// ==========================================================================

function setupMarketingSite() {
  // Feature Tabs Switcher (PRD §5)
  const tabButtons = document.querySelectorAll('.feature-tabs-nav .f-tab-btn');
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      tabButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const targetId = btn.getAttribute('data-tab');
      document.querySelectorAll('.feature-panel').forEach(p => p.classList.remove('active'));
      const activePanel = document.getElementById(targetId);
      if (activePanel) activePanel.classList.add('active');
    });
  });

  // FAQ Accordion
  const faqQuestions = document.querySelectorAll('.faq-question');
  faqQuestions.forEach(q => {
    q.addEventListener('click', () => {
      const parent = q.parentElement;
      parent.classList.toggle('open');
    });
  });

  // Interactive Keystroke Search Simulator
  const simInput = document.getElementById('sim-input');
  const simContainer = document.getElementById('sim-results-container');
  const mockSnippets = [
    { title: 'feat(look-system): implement hierarchical session explorer & AES-256 sync', app: 'VS Code', time: 'Today at 11:42 AM', match: '98%' },
    { title: 'Reviewing pull request checklist and database migration scripts for Neon Postgres', app: 'Google Chrome', time: 'Yesterday at 4:15 PM', match: '92%' },
    { title: 'ssh -i ~/.ssh/keyflow-deploy.pem admin@api.keyflow.io -p 2200', app: 'Terminal', time: '2 days ago', match: '89%' },
    { title: 'curl -X POST https://api.keyflow.io/api/v1/activity/batch -H "Authorization: Bearer ***"', app: 'Postman', time: '3 days ago', match: '85%' }
  ];

  simInput?.addEventListener('input', (e) => {
    const val = e.target.value.toLowerCase();
    const filtered = mockSnippets.filter(s => s.title.toLowerCase().includes(val) || s.app.toLowerCase().includes(val));
    if (simContainer) {
      if (filtered.length === 0) {
        simContainer.innerHTML = '<div class="text-muted" style="padding: 12px; font-size: 13px;">No matching past snippets found. Try typing "feat" or "postgres".</div>';
      } else {
        simContainer.innerHTML = filtered.map(s => `
          <div class="sim-snippet-item">
            <div>
              <strong style="color: var(--text-primary); font-size: 13px;">${s.title}</strong>
              <div style="font-size: 11px; color: var(--text-muted);">${s.app} • ${s.time} • ${s.match} match</div>
            </div>
            <span class="badge" style="font-size: 10px;">Press Enter to Reinsert</span>
          </div>
        `).join('');
      }
    }
  });

  // Switch between Marketing & Live Dashboard View (Protected by Auth)
  const btnOpenDash = document.getElementById('btn-open-dashboard');
  const btnBackSite = document.getElementById('btn-back-to-site');
  const linkFooterDash = document.getElementById('link-footer-dashboard');

  btnOpenDash?.addEventListener('click', () => {
    if (!currentUser || !authToken) {
      document.getElementById('auth-modal').style.display = 'flex';
      showAuthAlert('Please sign in to access the Look System Dashboard.', 'info');
      return;
    }
    document.body.classList.add('dashboard-mode');
    window.scrollTo({ top: 0, behavior: 'smooth' });
    refreshAllDashboardData();
  });

  linkFooterDash?.addEventListener('click', (e) => {
    e.preventDefault();
    if (!currentUser || !authToken) {
      document.getElementById('auth-modal').style.display = 'flex';
      showAuthAlert('Please sign in to access the Look System Dashboard.', 'info');
      return;
    }
    document.body.classList.add('dashboard-mode');
    window.scrollTo({ top: 0, behavior: 'smooth' });
    refreshAllDashboardData();
  });

  btnBackSite?.addEventListener('click', () => {
    document.body.classList.remove('dashboard-mode');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // Lead Forms Handling
  document.getElementById('form-request-access')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = document.getElementById('req-name')?.value;
    showToast(`Thank you, ${name}! Your access request has been recorded.`, 'success');
    e.target.reset();
  });

  document.getElementById('form-notify-builds')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const email = document.getElementById('notify-email')?.value;
    showToast(`Subscribed! Release announcements will be sent to ${email}.`, 'success');
    e.target.reset();
  });
}

// ==========================================================================
// Downloads Grid & Client-Side OS Auto-Detection
// ==========================================================================

async function setupDownloadsGrid() {
  const container = document.getElementById('downloads-grid-container');
  if (!container) return;

  const detectedPlatform = detectVisitorOS();

  try {
    const res = await fetch('releases.json');
    if (!res.ok) throw new Error('Could not load releases.json');
    const releases = await res.json();

    if (!Array.isArray(releases) || releases.length === 0) {
      container.innerHTML = '<div class="text-muted text-center py-4">No published release packages found.</div>';
      return;
    }

    container.innerHTML = releases.map((rel) => {
      const isRecommended = rel.platform === detectedPlatform;
      const downloadUrl = rel.fileUrl || rel.testflightUrl || '#';
      const buttonLabel = rel.platform === 'ios' ? 'Join TestFlight' : `Download for ${rel.displayName}`;

      const platformIcons = {
        windows: '🪟',
        macos: '🍎',
        android: '🤖',
        ios: '📱'
      };

      const iconEmoji = platformIcons[rel.platform] || '📦';

      return `
        <div class="platform-card ${isRecommended ? 'recommended' : ''}">
          ${isRecommended ? '<span class="recommended-pill">Recommended for your device</span>' : ''}
          <div class="platform-header">
            <div class="platform-icon">${iconEmoji}</div>
            <h3 class="platform-title">${rel.displayName}</h3>
            <div class="platform-version">Version ${rel.version} • ${rel.sizeMB}</div>
          </div>

          <ul class="platform-specs">
            <li><span class="spec-check">✓</span> ${rel.systemRequirements}</li>
            ${(rel.changelog || []).map(item => `<li><span class="spec-check">✓</span> ${item}</li>`).join('')}
          </ul>

          <a href="${downloadUrl}" class="btn ${isRecommended ? 'btn-primary' : 'btn-outline'} w-100" target="_blank" rel="noopener">
            ${buttonLabel}
          </a>
        </div>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to render downloads grid:', err);
    container.innerHTML = '<div class="text-muted text-center py-4">Direct release links are available on GitHub Releases (v1.0.0).</div>';
  }
}

function detectVisitorOS() {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('win')) return 'windows';
  if (ua.includes('mac') && !ua.includes('iphone') && !ua.includes('ipad')) return 'macos';
  if (ua.includes('android')) return 'android';
  if (ua.includes('iphone') || ua.includes('ipad') || ua.includes('ipod')) return 'ios';
  return 'windows';
}

// ==========================================================================
// Authentication Modal & Handlers
// ==========================================================================

function setupAuthModal() {
  const modal = document.getElementById('auth-modal');
  const btnNavTrigger = document.getElementById('btn-nav-auth');
  const userChip = document.getElementById('user-chip-btn');
  const btnLogout = document.getElementById('btn-logout');
  const btnClose = document.getElementById('btn-close-auth');
  const tabSignIn = document.getElementById('tab-btn-signin');
  const tabSignUp = document.getElementById('tab-btn-signup');
  const formSignIn = document.getElementById('form-signin');
  const formSignUp = document.getElementById('form-signup');
  const btnSubmitSignIn = document.getElementById('btn-submit-signin');
  const btnSubmitSignUp = document.getElementById('btn-submit-signup');

  const showModal = () => {
    hideAuthAlert();
    if (modal) modal.style.display = 'flex';
  };

  const hideModal = () => {
    hideAuthAlert();
    if (modal) modal.style.display = 'none';
  };

  btnNavTrigger?.addEventListener('click', () => {
    if (currentUser) {
      document.body.classList.toggle('dashboard-mode');
      if (document.body.classList.contains('dashboard-mode')) {
        refreshAllDashboardData();
      }
    } else {
      showModal();
    }
  });

  userChip?.addEventListener('click', showModal);
  btnClose?.addEventListener('click', hideModal);

  // Logout Handler
  btnLogout?.addEventListener('click', () => {
    safeRemoveItem('look_jwt_token');
    authToken = '';
    currentUser = null;
    currentSessionId = null;
    updateUserUI();
    document.body.classList.remove('dashboard-mode');
    showToast('You have been signed out.', 'info');
  });

  tabSignIn?.addEventListener('click', () => {
    hideAuthAlert();
    tabSignIn.classList.add('active');
    tabSignUp?.classList.remove('active');
    formSignIn.style.display = 'block';
    formSignUp.style.display = 'none';
  });

  tabSignUp?.addEventListener('click', () => {
    hideAuthAlert();
    tabSignUp.classList.add('active');
    tabSignIn?.classList.remove('active');
    formSignUp.style.display = 'block';
    formSignIn.style.display = 'none';
  });

  // Handle Sign In Submit
  formSignIn?.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideAuthAlert();

    const email = document.getElementById('signin-email')?.value?.trim();
    const password = document.getElementById('signin-password')?.value;

    if (btnSubmitSignIn) {
      btnSubmitSignIn.disabled = true;
      btnSubmitSignIn.textContent = 'Signing in...';
    }

    try {
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || data.message || 'Invalid email or password');
      }

      authToken = data.token;
      safeSetItem('look_jwt_token', authToken);
      currentUser = data.user;
      updateUserUI();
      hideModal();

      const name = currentUser.fullName || currentUser.full_name || 'Owner';
      showToast(`Welcome back, ${name}!`, 'success');
      document.body.classList.add('dashboard-mode');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      await refreshAllDashboardData();
    } catch (err) {
      showAuthAlert(err.message, 'error');
    } finally {
      if (btnSubmitSignIn) {
        btnSubmitSignIn.disabled = false;
        btnSubmitSignIn.textContent = 'Sign In to Workstation';
      }
    }
  });

  // Handle Sign Up Submit
  formSignUp?.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideAuthAlert();

    const fullName = document.getElementById('signup-name')?.value?.trim();
    const email = document.getElementById('signup-email')?.value?.trim();
    const password = document.getElementById('signup-password')?.value;
    const organizationName = document.getElementById('signup-org')?.value?.trim();

    if (btnSubmitSignUp) {
      btnSubmitSignUp.disabled = true;
      btnSubmitSignUp.textContent = 'Creating account...';
    }

    try {
      const res = await fetch(`${API_BASE}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullName, email, password, organizationName, role: 'admin' })
      });
      const data = await res.json();
      if (!res.ok) {
        const errorMsg = data.error || data.message || 'Registration failed';
        if (res.status === 409 || errorMsg.toLowerCase().includes('already registered')) {
          showAuthAlert('This email is already registered. Switched to Sign In.', 'info');
          tabSignIn?.click();
          if (document.getElementById('signin-email')) {
            document.getElementById('signin-email').value = email;
          }
          if (document.getElementById('signin-password')) {
            document.getElementById('signin-password').focus();
          }
          return;
        }
        throw new Error(errorMsg);
      }

      authToken = data.token;
      safeSetItem('look_jwt_token', authToken);
      currentUser = data.user;
      updateUserUI();
      hideModal();

      const name = currentUser.fullName || currentUser.full_name || 'Owner';
      showToast(`Account created! Welcome, ${name}.`, 'success');
      document.body.classList.add('dashboard-mode');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      await refreshAllDashboardData();
    } catch (err) {
      showAuthAlert(err.message, 'error');
    } finally {
      if (btnSubmitSignUp) {
        btnSubmitSignUp.disabled = false;
        btnSubmitSignUp.textContent = 'Create Account & Start Session';
      }
    }
  });
}

async function verifyAuthOrPrompt() {
  if (authToken) {
    try {
      const res = await fetch(`${API_BASE}/auth/me`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      const data = await res.json();
      if (data.user) {
        currentUser = data.user;
        updateUserUI();
      } else {
        authToken = '';
        safeRemoveItem('look_jwt_token');
        updateUserUI();
      }
    } catch {
      updateUserUI();
    }
  } else {
    updateUserUI();
  }
}

function updateUserUI() {
  const dashBtn = document.getElementById('btn-open-dashboard');
  const logoutBtn = document.getElementById('btn-logout');
  const navAuthBtn = document.getElementById('btn-nav-auth');
  const userName = document.getElementById('user-name');
  const userRole = document.getElementById('user-role');
  const userAvatar = document.getElementById('user-avatar');

  if (currentUser && authToken) {
    const nameStr = currentUser.fullName || 
                    currentUser.fullname || 
                    currentUser.full_name || 
                    (currentUser.email ? currentUser.email.split('@')[0] : 'Rama Krishna');

    if (dashBtn) dashBtn.style.display = 'inline-flex';
    if (logoutBtn) logoutBtn.style.display = 'block';
    if (userName) userName.textContent = nameStr;
    if (userRole) userRole.textContent = currentUser.role === 'admin' ? 'Administrator' : 'Team Member';
    
    const initials = nameStr
      .split(/[ ._@]+/)
      .filter(Boolean)
      .map(n => n[0])
      .join('')
      .substring(0, 2)
      .toUpperCase() || 'RK';

    if (userAvatar) userAvatar.textContent = initials;
    if (navAuthBtn) navAuthBtn.textContent = `Dashboard (${nameStr.split(' ')[0]})`;
  } else {
    if (dashBtn) dashBtn.style.display = 'none';
    if (logoutBtn) logoutBtn.style.display = 'none';
    if (userName) userName.textContent = 'Guest / Visitor';
    if (userRole) userRole.textContent = 'Click to Sign In';
    if (userAvatar) userAvatar.textContent = 'KF';
    if (navAuthBtn) navAuthBtn.textContent = 'Sign In / Register';
  }
}

// ==========================================================================
// Dashboard Data Refresh & Navigation
// ==========================================================================

async function refreshAllDashboardData() {
  await Promise.allSettled([
    loadOverviewData(),
    loadTypingHistory(),
    loadSessions(),
    loadAppBreakdown(),
    loadExclusions()
  ]);
}

function setupNavigation() {
  const navButtons = document.querySelectorAll('.sidebar .f-tab-btn');
  navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      navButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const tabId = btn.getAttribute('data-tab');
      document.querySelectorAll('#dashboard-container .tab-content').forEach(t => t.classList.remove('active'));
      const activeTab = document.getElementById(`tab-${tabId}`);
      if (activeTab) activeTab.classList.add('active');

      const titles = {
        overview: 'Executive Overview',
        typing: 'Cross-Device Typing History',
        sessions: 'Monitoring Session Explorer',
        search: 'Multi-Criteria Search & Filtering',
        apps: 'Application Telemetry Matrix',
        admin: 'Admin & Organization Controls',
        privacy: 'Privacy & Exclusions'
      };
      document.getElementById('page-title').textContent = titles[tabId] || 'Look System';

      if (tabId === 'typing') loadTypingHistory();
      if (tabId === 'sessions') loadSessions();
      if (tabId === 'apps') loadAppBreakdown();
      if (tabId === 'privacy') loadExclusions();
    });
  });
}

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
        showToast(`Session started: ${data.sessionId.substring(0, 8)}...`, 'success');
        refreshAllDashboardData();
      }
    } catch (err) {
      showToast(`Could not start session: ${err.message}`, 'error');
    }
  });

  document.getElementById('btn-pause-session-header')?.addEventListener('click', async () => {
    if (!currentSessionId) {
      showToast('No active session to pause.', 'info');
      return;
    }
    try {
      await fetch(`${API_BASE}/activity/sessions/pause`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`
        },
        body: JSON.stringify({ sessionId: currentSessionId })
      });
      showToast('Session paused.', 'info');
    } catch (err) {
      showToast(`Error pausing session: ${err.message}`, 'error');
    }
  });

  document.getElementById('btn-stop-session-header')?.addEventListener('click', async () => {
    if (!currentSessionId) {
      showToast('No active session to stop.', 'info');
      return;
    }
    try {
      await fetch(`${API_BASE}/activity/sessions/stop`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`
        },
        body: JSON.stringify({ sessionId: currentSessionId })
      });
      showToast('Session stopped and archived.', 'success');
      currentSessionId = null;
      refreshAllDashboardData();
    } catch (err) {
      showToast(`Error stopping session: ${err.message}`, 'error');
    }
  });
}

// ==========================================================================
// Cross-Device Typing History
// ==========================================================================

function setupTypingHistory() {
  document.getElementById('btn-search-typing')?.addEventListener('click', () => {
    const q = document.getElementById('typing-keyword-input')?.value || '';
    const appName = document.getElementById('typing-app-input')?.value || '';
    loadTypingHistory(q, appName);
  });

  document.getElementById('typing-keyword-input')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const q = document.getElementById('typing-keyword-input')?.value || '';
      const appName = document.getElementById('typing-app-input')?.value || '';
      loadTypingHistory(q, appName);
    }
  });
}

async function loadTypingHistory(q = '', appName = '') {
  const container = document.getElementById('typing-history-cards-container');
  if (!container) return;

  if (!authToken) {
    container.innerHTML = '<div class="text-muted text-center py-4">Please sign in to access your cross-device typing history.</div>';
    return;
  }

  try {
    const url = new URL(`${API_BASE}/activity/typing-history`);
    if (q) url.searchParams.append('q', q);
    if (appName) url.searchParams.append('appName', appName);

    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();
    const history = data.history || [];

    if (history.length === 0) {
      container.innerHTML = `
        <div class="text-muted text-center py-4">
          No typing snippets recorded yet. As you type on any enrolled device, permitted snippets will appear here automatically.
        </div>
      `;
      return;
    }

    container.innerHTML = history.map((item) => {
      const formattedDate = new Date(item.capturedAt).toLocaleString();

      return `
        <div class="typing-card">
          <div class="typing-card-header">
            <div class="typing-card-meta">
              <span class="device-badge">${item.deviceName || 'Workstation'}</span>
              <strong style="color: var(--accent-indigo);">${item.appName}</strong>
              <span>•</span>
              <span>${formattedDate}</span>
            </div>
            ${item.isExcluded ? '<span class="badge" style="color: var(--accent-red);">Excluded by Privacy</span>' : ''}
          </div>
          <div class="typing-card-content">${item.content || '—'}</div>
        </div>
      `;
    }).join('');
  } catch (err) {
    console.error('Failed to fetch typing history:', err);
    container.innerHTML = `<div class="text-muted text-center py-4">Unable to connect to typing history service.</div>`;
  }
}

// ==========================================================================
// Dashboard Overview, Sessions, Breakdown, Exclusions
// ==========================================================================

async function loadOverviewData() {
  if (!authToken) return;

  try {
    const res = await fetch(`${API_BASE}/activity/summary`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();

    if (data.metrics) {
      const hours = Math.floor((data.metrics.totalDurationSeconds || 0) / 3600);
      const mins = Math.floor(((data.metrics.totalDurationSeconds || 0) % 3600) / 60);
      document.getElementById('kpi-duration').textContent = `${hours}h ${mins}m`;
      document.getElementById('kpi-logs').textContent = Number(data.metrics.logCount || 0).toLocaleString();
      document.getElementById('kpi-productivity').textContent = `${data.metrics.productivityScore || 0}%`;
    }

    const topAppsContainer = document.getElementById('top-apps-container');
    if (topAppsContainer && Array.isArray(data.topApps) && data.topApps.length > 0) {
      topAppsContainer.innerHTML = data.topApps.map(app => `
        <div style="display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid var(--border-color);">
          <strong>${app.appName}</strong>
          <span style="color: var(--text-muted);">${Math.round(app.duration / 60)} mins</span>
        </div>
      `).join('');
    }
  } catch (err) {
    console.warn('Overview telemetry fetch:', err);
  }
}

async function loadSessions() {
  const container = document.getElementById('sessions-list-container');
  if (!container || !authToken) return;

  try {
    const res = await fetch(`${API_BASE}/activity/sessions`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();
    const sessions = data.sessions || [];

    if (sessions.length === 0) {
      container.innerHTML = '<div class="text-muted text-center py-4">No recorded monitoring sessions.</div>';
      return;
    }

    container.innerHTML = sessions.map(s => `
      <div style="padding: 14px; background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-sm); margin-bottom: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
          <strong>Session ID: ${s.id.substring(0, 8)}...</strong>
          <span class="badge ${s.status === 'active' ? 'badge-emerald' : ''}">${s.status.toUpperCase()}</span>
        </div>
        <div style="font-size: 12px; color: var(--text-muted);">
          Started: ${new Date(s.started_at).toLocaleString()} • Device: ${s.device_name || 'Workstation'}
        </div>
      </div>
    `).join('');
  } catch (err) {
    container.innerHTML = '<div class="text-muted text-center py-4">Could not load session explorer.</div>';
  }
}

async function loadAppBreakdown() {
  const container = document.getElementById('app-breakdown-container');
  if (!container || !authToken) return;

  try {
    const res = await fetch(`${API_BASE}/activity/summary`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();
    const topApps = data.topApps || [];

    if (topApps.length === 0) {
      container.innerHTML = '<div class="text-muted text-center py-4">No application telemetry recorded yet.</div>';
      return;
    }

    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>Application Name</th>
            <th>Logged Duration</th>
            <th>Category</th>
          </tr>
        </thead>
        <tbody>
          ${topApps.map(a => `
            <tr>
              <td><strong>${a.appName}</strong></td>
              <td>${Math.round(a.duration / 60)} minutes</td>
              <td><span class="badge">Productivity</span></td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    container.innerHTML = '<div class="text-muted text-center py-4">Could not load application matrix.</div>';
  }
}

function setupSearch() {
  document.getElementById('btn-execute-search')?.addEventListener('click', async () => {
    const q = document.getElementById('search-keyword-input')?.value || '';
    const appName = document.getElementById('search-app-input')?.value || '';
    const tbody = document.getElementById('search-results-body');
    if (!tbody || !authToken) return;

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
        tbody.innerHTML = '<tr><td colspan="4" class="text-muted text-center py-4">No matching records found.</td></tr>';
        return;
      }

      tbody.innerHTML = results.map(r => `
        <tr>
          <td>${new Date(r.startedAt).toLocaleString()}</td>
          <td><span class="device-badge">${r.deviceName || 'Device'}</span></td>
          <td><strong>${r.appName}</strong></td>
          <td>${r.windowTitle || '—'}</td>
        </tr>
      `).join('');
    } catch (err) {
      showToast(`Search error: ${err.message}`, 'error');
    }
  });
}

function setupExclusions() {
  document.getElementById('btn-add-exclusion')?.addEventListener('click', async () => {
    const appName = document.getElementById('input-new-exclusion')?.value?.trim();
    if (!appName) return;

    try {
      await fetch(`${API_BASE}/activity/privacy/exclusions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`
        },
        body: JSON.stringify({ appName })
      });
      showToast(`Excluded ${appName} from monitoring.`, 'success');
      document.getElementById('input-new-exclusion').value = '';
      loadExclusions();
    } catch (err) {
      showToast(`Could not add exclusion: ${err.message}`, 'error');
    }
  });
}

async function loadExclusions() {
  const container = document.getElementById('exclusion-chips-container');
  if (!container || !authToken) return;

  try {
    const res = await fetch(`${API_BASE}/activity/privacy/exclusions`, {
      headers: { Authorization: `Bearer ${authToken}` }
    });
    const data = await res.json();
    const exclusions = data.exclusions || [];

    if (exclusions.length === 0) {
      container.innerHTML = '<div class="text-muted py-2">No custom application exclusions configured.</div>';
      return;
    }

    container.innerHTML = `
      <div style="display: flex; flex-wrap: wrap; gap: 8px; padding-top: 8px;">
        ${exclusions.map(ex => `
          <span class="badge" style="background: var(--bg-surface); color: var(--accent-red); border-color: rgba(220, 38, 38, 0.2); font-size: 13px;">
            🔒 ${ex.app_name || ex.appName}
          </span>
        `).join('')}
      </div>
    `;
  } catch (err) {
    container.innerHTML = '<div class="text-muted">Could not load exclusions.</div>';
  }
}

function setupAdminControls() {
  document.getElementById('btn-purge-now')?.addEventListener('click', async () => {
    try {
      const res = await fetch(`${API_BASE}/admin/purge`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${authToken}` }
      });
      const data = await res.json();
      showToast(`Purge completed. ${data.purgedCount || 0} historical records permanently deleted.`, 'success');
      refreshAllDashboardData();
    } catch (err) {
      showToast(`Purge notice: ${err.message}`, 'info');
    }
  });
}
