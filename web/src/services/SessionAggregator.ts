/**
 * KeyFlow Session Aggregation & Debouncing Engine
 * Intelligently aggregates keystrokes into coherent paragraph sessions
 * per app, window title, and device with 2.5s inactivity debounce & 60s session termination.
 */

export interface DraftSnapshot {
  timestamp: string;
  text: string;
  charCount: number;
}

export interface TypingSession {
  id: string;
  userId?: string;
  deviceName: string;
  appName: string;
  windowTitle?: string;
  content: string;
  characterCount: number;
  wordCount: number;
  startedAt: string;
  updatedAt: string;
  isFavorite: boolean;
  draftHistory: DraftSnapshot[];
  isFinalized?: boolean;
}

export interface ClipboardEntry {
  id: string;
  userId?: string;
  deviceName: string;
  sourceApp?: string;
  content: string;
  contentType: 'text' | 'url' | 'code';
  isPinned: boolean;
  createdAt: string;
}

export interface SessionAggregatorConfig {
  inactivityDebounceMs?: number; // Default: 2500ms (2.5s)
  sessionTimeoutMs?: number;     // Default: 60000ms (60s)
  blacklistedApps?: string[];
  sensitiveTitlePatterns?: RegExp[];
  onSessionUpdate?: (session: TypingSession) => void | Promise<void>;
  onSessionFinalize?: (session: TypingSession) => void | Promise<void>;
  onClipboardCaptured?: (entry: ClipboardEntry) => void | Promise<void>;
}

export class SessionAggregator {
  private inactivityDebounceMs: number;
  private sessionTimeoutMs: number;
  private blacklistedApps: Set<string>;
  private sensitiveTitlePatterns: RegExp[];
  
  private onSessionUpdate?: (session: TypingSession) => void | Promise<void>;
  private onSessionFinalize?: (session: TypingSession) => void | Promise<void>;
  private onClipboardCaptured?: (entry: ClipboardEntry) => void | Promise<void>;

  private activeSessions: Map<string, TypingSession> = new Map();
  private debounceTimers: Map<string, any> = new Map();
  private sessionExpiryTimers: Map<string, any> = new Map();
  private lastActivityTimes: Map<string, number> = new Map();

  constructor(config: SessionAggregatorConfig = {}) {
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
  }

  /**
   * Generates a standard UUID v4
   */
  public generateUUID(): string {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID();
    }
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  /**
   * Compute standard word count
   */
  public static calculateWordCount(text: string): number {
    if (!text || !text.trim()) return 0;
    return text.trim().split(/\s+/).filter(Boolean).length;
  }

  /**
   * Generates a composite session grouping key
   */
  private getSessionKey(appName: string, windowTitle: string = '', deviceName: string = 'Desktop'): string {
    return `${appName.trim().toLowerCase()}::${windowTitle.trim().toLowerCase()}::${deviceName.trim().toLowerCase()}`;
  }

  /**
   * Validates if the event or field is privacy sensitive
   */
  public isPrivacySensitive(appName: string, windowTitle: string = '', isPasswordField: boolean = false): boolean {
    if (isPasswordField) return true;
    if (this.blacklistedApps.has(appName.toLowerCase())) return true;

    // Exempt calculator & utility tools from title filtering
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

  /**
   * Classify clipboard content type
   */
  public static classifyContentType(content: string): 'text' | 'url' | 'code' {
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

  /**
   * Ingest raw typing keystroke or text delta
   */
  public handleTypingInput(params: {
    appName: string;
    windowTitle?: string;
    deviceName?: string;
    text: string;
    isReplacement?: boolean;
    isPasswordField?: boolean;
    userId?: string;
  }): TypingSession | null {
    const {
      appName,
      windowTitle = '',
      deviceName = 'Desktop',
      text,
      isReplacement = false,
      isPasswordField = false,
      userId
    } = params;

    // Check privacy guards
    if (this.isPrivacySensitive(appName, windowTitle, isPasswordField)) {
      return null;
    }

    if (!text && !isReplacement) return null;

    const sessionKey = this.getSessionKey(appName, windowTitle, deviceName);
    const now = Date.now();
    const nowIso = new Date(now).toISOString();

    let session = this.activeSessions.get(sessionKey);
    const lastActivity = this.lastActivityTimes.get(sessionKey) || 0;

    // Check 60s session termination boundary
    if (session && now - lastActivity > this.sessionTimeoutMs) {
      this.finalizeSession(sessionKey);
      session = undefined;
    }

    if (!session) {
      // Start a brand new session paragraph
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
      // Update existing session paragraph (Upsert paradigm)
      if (isReplacement) {
        session.content = text;
      } else {
        // Concatenate / merge typing stream
        session.content = text;
      }

      session.characterCount = session.content.length;
      session.wordCount = SessionAggregator.calculateWordCount(session.content);
      session.updatedAt = nowIso;

      // Add snapshot to draft timeline if content meaningfully changed
      const lastSnap = session.draftHistory[session.draftHistory.length - 1];
      if (!lastSnap || Math.abs(session.content.length - lastSnap.charCount) >= 5) {
        session.draftHistory.push({
          timestamp: nowIso,
          text: session.content,
          charCount: session.content.length
        });
        // Limit draft history to 100 snapshots per session
        if (session.draftHistory.length > 100) {
          session.draftHistory.shift();
        }
      }
    }

    this.lastActivityTimes.set(sessionKey, now);

    // Reset 60s termination timer
    if (this.sessionExpiryTimers.has(sessionKey)) {
      clearTimeout(this.sessionExpiryTimers.get(sessionKey));
    }
    const expiryTimer = setTimeout(() => {
      this.finalizeSession(sessionKey);
    }, this.sessionTimeoutMs);
    this.sessionExpiryTimers.set(sessionKey, expiryTimer);

    // 2.5s Inactivity Debounce Buffer
    if (this.debounceTimers.has(sessionKey)) {
      clearTimeout(this.debounceTimers.get(sessionKey));
    }
    const debounceTimer = setTimeout(() => {
      this.dispatchDebouncedUpdate(sessionKey);
    }, this.inactivityDebounceMs);
    this.debounceTimers.set(sessionKey, debounceTimer);

    return session;
  }

  /**
   * Ingest clipboard copy event
   */
  public handleClipboardCopy(params: {
    content: string;
    sourceApp?: string;
    deviceName?: string;
    userId?: string;
  }): ClipboardEntry | null {
    const { content, sourceApp = 'System Clipboard', deviceName = 'Desktop', userId } = params;

    if (!content || !content.trim()) return null;

    const entry: ClipboardEntry = {
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

  /**
   * Dispatches debounced update (upsert) to backend/cloud
   */
  private dispatchDebouncedUpdate(sessionKey: string): void {
    const session = this.activeSessions.get(sessionKey);
    if (!session) return;

    if (this.onSessionUpdate) {
      this.onSessionUpdate({ ...session });
    }
  }

  /**
   * Finalizes active session paragraph
   */
  public finalizeSession(sessionKey: string): TypingSession | null {
    const session = this.activeSessions.get(sessionKey);
    if (!session) return null;

    // Clear timers
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

  /**
   * Finalize all active sessions (e.g. on app shutdown or blur)
   */
  public finalizeAll(): TypingSession[] {
    const finalized: TypingSession[] = [];
    for (const key of Array.from(this.activeSessions.keys())) {
      const sess = this.finalizeSession(key);
      if (sess) finalized.push(sess);
    }
    return finalized;
  }

  /**
   * Get all currently active session buffers
   */
  public getActiveSessions(): TypingSession[] {
    return Array.from(this.activeSessions.values()).map((s) => ({ ...s }));
  }
}
