/**
 * KeyFlow Session Aggregation & Debouncing Engine (Test Helper / Node.js)
 */

class SessionAggregator {
  constructor(config = {}) {
    this.inactivityDebounceMs = config.inactivityDebounceMs ?? 2500;
    this.sessionTimeoutMs = config.sessionTimeoutMs ?? 60000;
    this.blacklistedApps = new Set(
      (config.blacklistedApps || []).map((a) => a.toLowerCase())
    );
    this.sensitiveTitlePatterns = config.sensitiveTitlePatterns || [
      /password/i,
      /authenticator/i,
      /bitwarden/i,
      /1password/i,
      /keepass/i,
      /banking/i,
      /credential/i,
      /card details/i,
      /cvv/i,
    ];
    this.onSessionUpdate = config.onSessionUpdate;
    this.onSessionFinalize = config.onSessionFinalize;
    this.onClipboardCaptured = config.onClipboardCaptured;

    this.activeSessions = new Map();
    this.debounceTimers = new Map();
    this.sessionExpiryTimers = new Map();
    this.lastActivityTimes = new Map();
  }

  generateUUID() {
    const globalCrypto = typeof globalThis !== 'undefined' ? globalThis.crypto : null;
    if (globalCrypto) {
      if (typeof globalCrypto.randomUUID === 'function') {
        return globalCrypto.randomUUID();
      }
      if (typeof globalCrypto.getRandomValues === 'function') {
        const bytes = new Uint8Array(16);
        globalCrypto.getRandomValues(bytes);
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
        return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
      }
    }
    return `session-${Date.now()}-${(typeof performance !== 'undefined' ? performance.now() : 0).toString(36).replace('.', '')}`;
  }

  static calculateWordCount(text) {
    if (!text || !text.trim()) return 0;
    return text.trim().split(/\s+/).filter(Boolean).length;
  }

  getSessionKey(appName, windowTitle = '', deviceName = 'Desktop') {
    return `${appName.trim().toLowerCase()}::${windowTitle.trim().toLowerCase()}::${deviceName.trim().toLowerCase()}`;
  }

  isPrivacySensitive(appName, windowTitle = '', isPasswordField = false) {
    if (isPasswordField) return true;
    if (this.blacklistedApps.has(appName.toLowerCase())) return true;

    const lowerApp = appName.toLowerCase();
    if (lowerApp.includes('calc') || lowerApp.includes('calculator')) {
      return false;
    }

    for (const pattern of this.sensitiveTitlePatterns) {
      if (pattern.test(windowTitle)) {
        return true;
      }
    }
    return false;
  }

  static classifyContentType(content) {
    if (!content || !content.trim()) return 'text';
    const trimmed = content.trim();

    // 1. Check URL
    const urlPattern = /^(https?:\/\/|ftp:\/\/|www\.)[^\s/$.?#].[^\s]*$/i;
    if (urlPattern.test(trimmed)) {
      return 'url';
    }

    // 2. Check Code
    const codeIndicators = [
      /\b(const|let|var|function|return|import|export|class|interface|type|async|await)\b/g,
      /\b(def|class|lambda|import|from|elif|print)\b/g,
      /\b(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|JOIN|CREATE|DROP|ALTER)\b/gi,
      /\b(public|private|protected|void|static|final|struct|impl|fn)\b/g,
      /[{}();=>]{2,}/g,
      /^<(!DOCTYPE|html|div|span|p|a|ul|li|template|script|style)[\s>]/i,
      /^[a-zA-Z0-9_-]+\s*:\s*[a-zA-Z0-9#_-]+;$/,
      /{\s*"\w+"\s*:/
    ];

    let matchCount = 0;
    for (const regex of codeIndicators) {
      const matches = trimmed.match(regex);
      if (matches) {
        matchCount += matches.length;
      }
    }

    if (matchCount >= 2 || (trimmed.includes('\n') && matchCount >= 1)) {
      return 'code';
    }

    return 'text';
  }

  handleTypingInput(params) {
    const {
      appName,
      windowTitle = '',
      deviceName = 'Desktop',
      text,
      isReplacement = false,
      isPasswordField = false,
      userId
    } = params;

    if (this.isPrivacySensitive(appName, windowTitle, isPasswordField)) {
      return null;
    }

    if (!text && !isReplacement) return null;

    const sessionKey = this.getSessionKey(appName, windowTitle, deviceName);
    const now = Date.now();
    const nowIso = new Date(now).toISOString();

    let session = this.activeSessions.get(sessionKey);
    const lastActivity = this.lastActivityTimes.get(sessionKey) || 0;

    if (session && now - lastActivity > this.sessionTimeoutMs) {
      this.finalizeSession(sessionKey);
      session = undefined;
    }

    if (!session) {
      session = {
        id: this.generateUUID(),
        userId,
        deviceName,
        appName,
        windowTitle,
        content: text,
        characterCount: text.length,
        wordCount: SessionAggregator.calculateWordCount(text),
        startedAt: nowIso,
        updatedAt: nowIso,
        isFavorite: false,
        draftHistory: [
          {
            timestamp: nowIso,
            text,
            charCount: text.length
          }
        ]
      };
      this.activeSessions.set(sessionKey, session);
    } else {
      session.content = text;
      session.characterCount = session.content.length;
      session.wordCount = SessionAggregator.calculateWordCount(session.content);
      session.updatedAt = nowIso;

      const lastSnap = session.draftHistory[session.draftHistory.length - 1];
      if (!lastSnap || Math.abs(session.content.length - lastSnap.charCount) >= 5) {
        session.draftHistory.push({
          timestamp: nowIso,
          text: session.content,
          charCount: session.content.length
        });
        if (session.draftHistory.length > 100) {
          session.draftHistory.shift();
        }
      }
    }

    this.lastActivityTimes.set(sessionKey, now);

    if (this.sessionExpiryTimers.has(sessionKey)) {
      clearTimeout(this.sessionExpiryTimers.get(sessionKey));
    }
    const expiryTimer = setTimeout(() => {
      this.finalizeSession(sessionKey);
    }, this.sessionTimeoutMs);
    this.sessionExpiryTimers.set(sessionKey, expiryTimer);

    if (this.debounceTimers.has(sessionKey)) {
      clearTimeout(this.debounceTimers.get(sessionKey));
    }
    const debounceTimer = setTimeout(() => {
      this.dispatchDebouncedUpdate(sessionKey);
    }, this.inactivityDebounceMs);
    this.debounceTimers.set(sessionKey, debounceTimer);

    return session;
  }

  handleClipboardCopy(params) {
    const { content, sourceApp = 'System Clipboard', deviceName = 'Desktop', userId } = params;

    if (!content || !content.trim()) return null;

    const entry = {
      id: this.generateUUID(),
      userId,
      deviceName,
      sourceApp,
      content,
      contentType: SessionAggregator.classifyContentType(content),
      isPinned: false,
      createdAt: new Date().toISOString()
    };

    if (this.onClipboardCaptured) {
      this.onClipboardCaptured(entry);
    }

    return entry;
  }

  dispatchDebouncedUpdate(sessionKey) {
    const session = this.activeSessions.get(sessionKey);
    if (!session) return;

    if (this.onSessionUpdate) {
      this.onSessionUpdate({ ...session });
    }
  }

  finalizeSession(sessionKey) {
    const session = this.activeSessions.get(sessionKey);
    if (!session) return null;

    if (this.debounceTimers.has(sessionKey)) {
      clearTimeout(this.debounceTimers.get(sessionKey));
      this.debounceTimers.delete(sessionKey);
    }
    if (this.sessionExpiryTimers.has(sessionKey)) {
      clearTimeout(this.sessionExpiryTimers.get(sessionKey));
      this.sessionExpiryTimers.delete(sessionKey);
    }

    session.isFinalized = true;
    session.updatedAt = new Date().toISOString();

    if (this.onSessionFinalize) {
      this.onSessionFinalize({ ...session });
    }

    this.activeSessions.delete(sessionKey);
    this.lastActivityTimes.delete(sessionKey);
    return session;
  }

  finalizeAll() {
    const finalized = [];
    for (const key of Array.from(this.activeSessions.keys())) {
      const sess = this.finalizeSession(key);
      if (sess) finalized.push(sess);
    }
    return finalized;
  }

  getActiveSessions() {
    return Array.from(this.activeSessions.values()).map((s) => ({ ...s }));
  }
}

module.exports = { SessionAggregator };
