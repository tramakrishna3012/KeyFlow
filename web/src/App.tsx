import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { Sidebar } from './components/Sidebar';
import { TypingStreamFeed } from './components/TypingStreamFeed';
import { ClipboardHistoryFeed } from './components/ClipboardHistoryFeed';
import { ReplayDraftModal } from './components/ReplayDraftModal';
import { AuthModal } from './components/AuthModal';
import { SessionAggregator, type TypingSession, type ClipboardEntry } from './services/SessionAggregator';

export const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'typing' | 'clipboard'>('typing');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedApp, setSelectedApp] = useState('');
  const [selectedDevice, setSelectedDevice] = useState('');
  const [syncStatus, setSyncStatus] = useState<'synced' | 'debouncing' | 'offline'>('synced');
  
  const [sessions, setSessions] = useState<TypingSession[]>([]);
  const [clipboardEntries, setClipboardEntries] = useState<ClipboardEntry[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const [replaySession, setReplaySession] = useState<TypingSession | null>(null);
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [authToken, setAuthToken] = useState<string | null>(() => localStorage.getItem('kf_token'));
  const [currentUser, setCurrentUser] = useState<{ email: string; name: string }>(() => ({
    email: localStorage.getItem('kf_user_email') || 'tramakrishna3012@gmail.com',
    name: localStorage.getItem('kf_user_name') || 'Rama Krishna',
  }));

  // Initialize Session Aggregator instance
  const aggregator = useMemo(() => {
    return new SessionAggregator({
      inactivityDebounceMs: 2500, // 2.5s debouncing
      sessionTimeoutMs: 60000,    // 60s termination boundary
      onSessionUpdate: async (updatedSession) => {
        setSyncStatus('debouncing');
        try {
          // Upsert locally
          setSessions((prev) => {
            const idx = prev.findIndex((s) => s.id === updatedSession.id);
            if (idx !== -1) {
              const clone = [...prev];
              clone[idx] = updatedSession;
              return clone;
            }
            return [updatedSession, ...prev];
          });

          // Sync to backend if authenticated
          if (authToken) {
            await fetch('/api/v1/sessions/upsert', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${authToken}`,
              },
              body: JSON.stringify(updatedSession),
            });
          }
          setSyncStatus('synced');
        } catch (err) {
          console.error('Session sync error:', err);
          setSyncStatus('offline');
        }
      },
      onClipboardCaptured: async (newEntry) => {
        setClipboardEntries((prev) => [newEntry, ...prev]);
        if (authToken) {
          try {
            await fetch('/api/v1/clipboard/insert', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${authToken}`,
              },
              body: JSON.stringify(newEntry),
            });
          } catch (err) {
            console.error('Clipboard sync error:', err);
          }
        }
      },
    });
  }, [authToken]);

  // Fetch initial data
  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      if (authToken) {
        // Fetch sessions
        const sessRes = await fetch(`/api/v1/sessions?limit=100`, {
          headers: { Authorization: `Bearer ${authToken}` },
        });
        if (sessRes.ok) {
          const sessData = await sessRes.json();
          if (sessData.sessions) setSessions(sessData.sessions);
        }

        // Fetch clipboard
        const clipRes = await fetch(`/api/v1/clipboard?limit=100`, {
          headers: { Authorization: `Bearer ${authToken}` },
        });
        if (clipRes.ok) {
          const clipData = await clipRes.json();
          if (clipData.entries) setClipboardEntries(clipData.entries);
        }
      } else {
        // Initialize rich mock / local state
        setSessions([
          {
            id: 'mock-session-1',
            appName: 'Chrome',
            windowTitle: 'KeyFlow Architecture & PRD — Google Docs',
            deviceName: 'Motorola Edge 40',
            content: 'KeyFlow captures text recovery and clipboard synchronization seamlessly across all platforms with 2.5s debouncing and zero duplicate database rows.',
            characterCount: 147,
            wordCount: 19,
            startedAt: new Date(Date.now() - 3600000).toISOString(),
            updatedAt: new Date(Date.now() - 3500000).toISOString(),
            isFavorite: true,
            draftHistory: [
              { timestamp: new Date(Date.now() - 3600000).toISOString(), text: 'KeyFlow captures text', charCount: 22 },
              { timestamp: new Date(Date.now() - 3550000).toISOString(), text: 'KeyFlow captures text recovery and clipboard sync', charCount: 48 },
              { timestamp: new Date(Date.now() - 3500000).toISOString(), text: 'KeyFlow captures text recovery and clipboard synchronization seamlessly across all platforms with 2.5s debouncing and zero duplicate database rows.', charCount: 147 },
            ],
          },
          {
            id: 'mock-session-2',
            appName: 'VS Code',
            windowTitle: 'SessionAggregator.ts — KeyFlow',
            deviceName: 'Desktop',
            content: 'export class SessionAggregator {\n  private inactivityDebounceMs = 2500;\n  private sessionTimeoutMs = 60000;\n}',
            characterCount: 97,
            wordCount: 10,
            startedAt: new Date(Date.now() - 7200000).toISOString(),
            updatedAt: new Date(Date.now() - 7100000).toISOString(),
            isFavorite: false,
            draftHistory: [
              { timestamp: new Date(Date.now() - 7200000).toISOString(), text: 'export class SessionAggregator {\n}', charCount: 34 },
              { timestamp: new Date(Date.now() - 7100000).toISOString(), text: 'export class SessionAggregator {\n  private inactivityDebounceMs = 2500;\n  private sessionTimeoutMs = 60000;\n}', charCount: 97 }
            ],
          },
          {
            id: 'mock-session-3',
            appName: 'Calculator',
            windowTitle: 'Calculator',
            deviceName: 'Motorola Edge 40',
            content: '75000 + 25000 = 100000',
            characterCount: 22,
            wordCount: 5,
            startedAt: new Date(Date.now() - 10800000).toISOString(),
            updatedAt: new Date(Date.now() - 10790000).toISOString(),
            isFavorite: false,
            draftHistory: [
              { timestamp: new Date(Date.now() - 10800000).toISOString(), text: '75000 + 25000 = 100000', charCount: 22 }
            ],
          }
        ]);

        setClipboardEntries([
          {
            id: 'clip-1',
            sourceApp: 'Chrome',
            deviceName: 'Motorola Edge 40',
            content: 'https://keyflow.tramakrishna3012.workers.dev',
            contentType: 'url',
            isPinned: true,
            createdAt: new Date(Date.now() - 1800000).toISOString(),
          },
          {
            id: 'clip-2',
            sourceApp: 'VS Code',
            deviceName: 'Desktop',
            content: 'function classifyContentType(content) {\n  if (content.startsWith("http")) return "url";\n  return "text";\n}',
            contentType: 'code',
            isPinned: false,
            createdAt: new Date(Date.now() - 3600000).toISOString(),
          },
          {
            id: 'clip-3',
            sourceApp: 'Slack',
            deviceName: 'Motorola Edge 40',
            content: 'Please verify the new session-aggregated cards on both mobile and web dashboard.',
            contentType: 'text',
            isPinned: false,
            createdAt: new Date(Date.now() - 5400000).toISOString(),
          }
        ]);
      }
    } catch (err) {
      console.error('Fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [authToken]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Derived filter lists
  const availableApps = useMemo(() => {
    const map = new Map<string, number>();
    for (const s of sessions) {
      map.set(s.appName, (map.get(s.appName) || 0) + 1);
    }
    return Array.from(map.entries()).map(([name, count]) => ({ name, count }));
  }, [sessions]);

  const availableDevices = useMemo(() => {
    const set = new Set<string>();
    for (const s of sessions) set.add(s.deviceName);
    for (const c of clipboardEntries) set.add(c.deviceName);
    return Array.from(set);
  }, [sessions, clipboardEntries]);

  // Filtered Sessions
  const filteredSessions = useMemo(() => {
    return sessions.filter((s) => {
      if (selectedApp && s.appName.toLowerCase() !== selectedApp.toLowerCase()) return false;
      if (selectedDevice && s.deviceName.toLowerCase() !== selectedDevice.toLowerCase()) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesContent = s.content.toLowerCase().includes(q);
        const matchesApp = s.appName.toLowerCase().includes(q);
        const matchesTitle = s.windowTitle?.toLowerCase().includes(q);
        if (!matchesContent && !matchesApp && !matchesTitle) return false;
      }
      return true;
    });
  }, [sessions, selectedApp, selectedDevice, searchQuery]);

  // Filtered Clipboard
  const filteredClipboard = useMemo(() => {
    return clipboardEntries.filter((c) => {
      if (selectedDevice && c.deviceName.toLowerCase() !== selectedDevice.toLowerCase()) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesContent = c.content.toLowerCase().includes(q);
        const matchesApp = c.sourceApp?.toLowerCase().includes(q);
        if (!matchesContent && !matchesApp) return false;
      }
      return true;
    });
  }, [clipboardEntries, selectedDevice, searchQuery]);

  const handleToggleFavorite = async (id: string) => {
    setSessions((prev) =>
      prev.map((s) => (s.id === id ? { ...s, isFavorite: !s.isFavorite } : s))
    );
    if (authToken) {
      try {
        await fetch(`/api/v1/sessions/${id}/favorite`, {
          method: 'PATCH',
          headers: { Authorization: `Bearer ${authToken}` },
        });
      } catch (err) {
        console.error('Favorite toggle error:', err);
      }
    }
  };

  const handleTogglePin = async (id: string) => {
    setClipboardEntries((prev) =>
      prev.map((c) => (c.id === id ? { ...c, isPinned: !c.isPinned } : c))
    );
    if (authToken) {
      try {
        await fetch(`/api/v1/clipboard/${id}/pin`, {
          method: 'PATCH',
          headers: { Authorization: `Bearer ${authToken}` },
        });
      } catch (err) {
        console.error('Pin toggle error:', err);
      }
    }
  };

  const handleDeleteSession = async (id: string) => {
    setSessions((prev) => prev.filter((s) => s.id !== id));
    if (authToken) {
      try {
        await fetch(`/api/v1/sessions/${id}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${authToken}` },
        });
      } catch (err) {
        console.error('Delete session error:', err);
      }
    }
  };

  const handleDeleteClipboard = async (id: string) => {
    setClipboardEntries((prev) => prev.filter((c) => c.id !== id));
    if (authToken) {
      try {
        await fetch(`/api/v1/clipboard/${id}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${authToken}` },
        });
      } catch (err) {
        console.error('Delete clipboard error:', err);
      }
    }
  };

  const handleSignOut = () => {
    localStorage.removeItem('kf_token');
    localStorage.removeItem('kf_user_email');
    localStorage.removeItem('kf_user_name');
    setAuthToken(null);
    setCurrentUser({ email: 'guest@keyflow.dev', name: 'Guest User' });
  };

  const handleAuthSuccess = (token: string, user: { email: string; name: string }) => {
    localStorage.setItem('kf_token', token);
    localStorage.setItem('kf_user_email', user.email);
    localStorage.setItem('kf_user_name', user.name);
    setAuthToken(token);
    setCurrentUser(user);
    fetchData();
  };

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100 font-sans antialiased">
      {/* Sidebar Navigation */}
      <Sidebar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        selectedApp={selectedApp}
        onSelectApp={setSelectedApp}
        availableApps={availableApps}
        selectedDevice={selectedDevice}
        onSelectDevice={setSelectedDevice}
        availableDevices={availableDevices}
        syncStatus={syncStatus}
        userEmail={currentUser.email}
        userName={currentUser.name}
        onSignOut={handleSignOut}
      />

      {/* Main Stream Area */}
      <main className="flex-1 flex flex-col min-w-0 bg-slate-950 overflow-y-auto">
        {activeTab === 'typing' ? (
          <TypingStreamFeed
            sessions={filteredSessions}
            isLoading={isLoading}
            onRefresh={fetchData}
            onToggleFavorite={handleToggleFavorite}
            onReplayDraft={(session) => setReplaySession(session)}
            onDelete={handleDeleteSession}
            selectedApp={selectedApp}
            selectedDevice={selectedDevice}
          />
        ) : (
          <ClipboardHistoryFeed
            entries={filteredClipboard}
            isLoading={isLoading}
            onRefresh={fetchData}
            onTogglePin={handleTogglePin}
            onDelete={handleDeleteClipboard}
          />
        )}
      </main>

      {/* Replay Draft Modal */}
      <ReplayDraftModal
        session={replaySession}
        isOpen={Boolean(replaySession)}
        onClose={() => setReplaySession(null)}
      />

      {/* Auth Modal */}
      <AuthModal
        isOpen={isAuthOpen}
        onClose={() => setIsAuthOpen(false)}
        onSuccess={handleAuthSuccess}
      />
    </div>
  );
};

export default App;
