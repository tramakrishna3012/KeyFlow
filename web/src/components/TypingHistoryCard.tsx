import React, { useState } from 'react';
import { 
  Copy, 
  Check, 
  Star, 
  Play, 
  Clock, 
  Monitor, 
  FileText, 
  Hash, 
  Sparkles,
  ExternalLink
} from 'lucide-react';
import type { TypingSession } from '../services/SessionAggregator';

interface TypingHistoryCardProps {
  session: TypingSession;
  onToggleFavorite?: (id: string) => void;
  onReplayDraft?: (session: TypingSession) => void;
  onDelete?: (id: string) => void;
}

export const TypingHistoryCard: React.FC<TypingHistoryCardProps> = ({
  session,
  onToggleFavorite,
  onReplayDraft,
  onDelete,
}) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(session.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Format relative timestamp
  const formatTime = (isoString: string) => {
    try {
      const date = new Date(isoString);
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    } catch {
      return isoString;
    }
  };

  // Calculate duration if available
  const calculateDuration = () => {
    try {
      const start = new Date(session.startedAt).getTime();
      const updated = new Date(session.updatedAt).getTime();
      const diffSec = Math.max(1, Math.round((updated - start) / 1000));
      if (diffSec < 60) return `${diffSec}s`;
      const mins = Math.floor(diffSec / 60);
      const secs = diffSec % 60;
      return `${mins}m ${secs}s`;
    } catch {
      return '1m';
    }
  };

  // Get application color / icon badge
  const getAppBadgeColor = (appName: string) => {
    const lower = appName.toLowerCase();
    if (lower.includes('chrome') || lower.includes('browser')) return 'bg-amber-500/10 text-amber-400 border-amber-500/20';
    if (lower.includes('code') || lower.includes('studio') || lower.includes('terminal')) return 'bg-blue-500/10 text-blue-400 border-blue-500/20';
    if (lower.includes('slack') || lower.includes('discord') || lower.includes('chat')) return 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';
    if (lower.includes('calc')) return 'bg-purple-500/10 text-purple-400 border-purple-500/20';
    return 'bg-indigo-500/10 text-indigo-400 border-indigo-500/20';
  };

  return (
    <div className="group relative bg-slate-900/80 backdrop-blur-md border border-slate-800/80 hover:border-indigo-500/40 rounded-xl p-5 transition-all duration-200 hover:shadow-xl hover:shadow-indigo-500/5 mb-4">
      {/* Card Header */}
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex items-center flex-wrap gap-2">
          {/* App Name Badge */}
          <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-semibold border ${getAppBadgeColor(session.appName)}`}>
            <FileText className="w-3.5 h-3.5" />
            {session.appName}
          </span>

          {/* Window Title (if present) */}
          {session.windowTitle && (
            <span className="text-xs text-slate-400 font-medium truncate max-w-[240px] md:max-w-[360px]" title={session.windowTitle}>
              • {session.windowTitle}
            </span>
          )}

          {/* Device Name Badge */}
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[11px] font-medium bg-slate-800/90 text-slate-300 border border-slate-700/50">
            <Monitor className="w-3 h-3 text-slate-400" />
            {session.deviceName}
          </span>
        </div>

        {/* Favorite & Replay Actions */}
        <div className="flex items-center gap-1 opacity-90 group-hover:opacity-100 transition-opacity">
          {session.draftHistory && session.draftHistory.length > 1 && (
            <button
              onClick={() => onReplayDraft?.(session)}
              className="flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-medium text-indigo-400 hover:text-indigo-300 bg-indigo-500/10 hover:bg-indigo-500/20 border border-indigo-500/20 transition-colors"
              title="Replay draft writing timeline"
            >
              <Play className="w-3 h-3 fill-indigo-400" />
              Replay Draft
            </button>
          )}

          <button
            onClick={() => onToggleFavorite?.(session.id)}
            className={`p-1.5 rounded-lg text-slate-400 hover:text-amber-400 hover:bg-slate-800 transition-colors ${
              session.isFavorite ? 'text-amber-400 bg-amber-400/10' : ''
            }`}
            title={session.isFavorite ? 'Favorited' : 'Add to favorites'}
          >
            <Star className={`w-4 h-4 ${session.isFavorite ? 'fill-amber-400' : ''}`} />
          </button>
        </div>
      </div>

      {/* Main Aggregated Paragraph Content */}
      <div className="bg-slate-950/60 rounded-lg p-4 border border-slate-800/60 mb-3.5">
        <p className="text-slate-100 font-normal leading-relaxed text-sm md:text-base whitespace-pre-wrap select-text font-sans">
          {session.content}
        </p>
      </div>

      {/* Card Footer Metrics & 1-Click Copy */}
      <div className="flex items-center justify-between text-xs text-slate-400 pt-1 border-t border-slate-800/40">
        <div className="flex items-center flex-wrap gap-4">
          <span className="flex items-center gap-1 text-slate-400" title="Started time">
            <Clock className="w-3.5 h-3.5 text-slate-500" />
            {formatTime(session.startedAt)}
          </span>

          <span className="flex items-center gap-1 text-slate-400" title="Active typing duration">
            <Sparkles className="w-3.5 h-3.5 text-amber-500/80" />
            {calculateDuration()}
          </span>

          <span className="flex items-center gap-1 text-slate-400" title="Word & Character count">
            <Hash className="w-3.5 h-3.5 text-slate-500" />
            {session.wordCount} words • {session.characterCount} chars
          </span>
        </div>

        {/* 1-Click Copy Button with Toast Feedback */}
        <button
          onClick={handleCopy}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-150 ${
            copied
              ? 'bg-emerald-500 text-white shadow-lg shadow-emerald-500/20'
              : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/20 hover:scale-105 active:scale-95'
          }`}
        >
          {copied ? (
            <>
              <Check className="w-3.5 h-3.5" />
              Copied!
            </>
          ) : (
            <>
              <Copy className="w-3.5 h-3.5" />
              Copy
            </>
          )}
        </button>
      </div>
    </div>
  );
};
