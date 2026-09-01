import React, { useState } from 'react';
import { 
  Copy, 
  Check, 
  Pin, 
  Trash2, 
  ExternalLink, 
  Code, 
  Link as LinkIcon, 
  FileText, 
  Monitor, 
  Clock 
} from 'lucide-react';
import type { ClipboardEntry } from '../services/SessionAggregator';

interface ClipboardHistoryCardProps {
  entry: ClipboardEntry;
  onTogglePin?: (id: string) => void;
  onDelete?: (id: string) => void;
}

export const ClipboardHistoryCard: React.FC<ClipboardHistoryCardProps> = ({
  entry,
  onTogglePin,
  onDelete,
}) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(entry.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const formatTime = (isoString: string) => {
    try {
      const date = new Date(isoString);
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    } catch {
      return isoString;
    }
  };

  // Render URL Preview Card
  const renderUrlPreview = (url: string) => {
    let domain = '';
    try {
      domain = new URL(url.startsWith('http') ? url : `https://${url}`).hostname;
    } catch {
      domain = url;
    }

    return (
      <div className="bg-slate-950/70 rounded-lg p-3.5 border border-slate-800/80 hover:border-indigo-500/30 transition-colors mb-3">
        <div className="flex items-center justify-between gap-2 mb-1.5">
          <span className="inline-flex items-center gap-1 text-xs font-semibold text-sky-400 bg-sky-500/10 px-2 py-0.5 rounded border border-sky-500/20">
            <LinkIcon className="w-3 h-3" />
            {domain}
          </span>
          <a
            href={url.startsWith('http') ? url : `https://${url}`}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1 text-xs text-indigo-400 hover:text-indigo-300 font-medium hover:underline"
          >
            Open <ExternalLink className="w-3 h-3" />
          </a>
        </div>
        <p className="text-sm text-slate-200 font-mono break-all line-clamp-2">
          {url}
        </p>
      </div>
    );
  };

  // Render Syntax Styled Code Block
  const renderCodeBlock = (code: string) => {
    const lines = code.split('\n');
    return (
      <div className="bg-slate-950/90 rounded-lg overflow-hidden border border-slate-800/90 font-mono text-xs mb-3 shadow-inner">
        <div className="flex items-center justify-between px-3 py-1.5 bg-slate-900/90 border-b border-slate-800 text-[11px] text-slate-400">
          <span className="flex items-center gap-1 font-medium text-purple-400">
            <Code className="w-3 h-3" /> Code Snippet
          </span>
          <span className="text-slate-500">{lines.length} lines</span>
        </div>
        <div className="p-3 overflow-x-auto max-h-64 space-y-0.5">
          {lines.map((line, idx) => (
            <div key={idx} className="flex gap-3 leading-relaxed">
              <span className="text-slate-600 select-none w-6 text-right font-mono text-[11px]">
                {idx + 1}
              </span>
              <span className="text-emerald-300 whitespace-pre font-mono">
                {line}
              </span>
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div
      className={`group relative bg-slate-900/80 backdrop-blur-md border rounded-xl p-4 transition-all duration-200 hover:shadow-xl mb-3.5 ${
        entry.isPinned
          ? 'border-indigo-500/50 bg-slate-900/95 shadow-lg shadow-indigo-500/5'
          : 'border-slate-800/80 hover:border-slate-700'
      }`}
    >
      {/* Header */}
      <div className="flex items-center justify-between gap-2 mb-2.5">
        <div className="flex items-center flex-wrap gap-2">
          {/* Content Type Pill */}
          <span
            className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-semibold border ${
              entry.contentType === 'code'
                ? 'bg-purple-500/10 text-purple-400 border-purple-500/20'
                : entry.contentType === 'url'
                ? 'bg-sky-500/10 text-sky-400 border-sky-500/20'
                : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
            }`}
          >
            {entry.contentType === 'code' && <Code className="w-3 h-3" />}
            {entry.contentType === 'url' && <LinkIcon className="w-3 h-3" />}
            {entry.contentType === 'text' && <FileText className="w-3 h-3" />}
            {entry.contentType.toUpperCase()}
          </span>

          {/* Source App */}
          {entry.sourceApp && (
            <span className="text-xs text-slate-400 font-medium truncate max-w-[180px]">
              {entry.sourceApp}
            </span>
          )}

          {/* Device Tag */}
          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-slate-800/80 text-slate-400 border border-slate-700/50">
            <Monitor className="w-2.5 h-2.5" />
            {entry.deviceName}
          </span>
        </div>

        {/* Pin & Delete Actions */}
        <div className="flex items-center gap-1">
          <button
            onClick={() => onTogglePin?.(entry.id)}
            className={`p-1.5 rounded-lg text-slate-400 hover:text-indigo-400 hover:bg-slate-800 transition-colors ${
              entry.isPinned ? 'text-indigo-400 bg-indigo-500/10 border border-indigo-500/20' : ''
            }`}
            title={entry.isPinned ? 'Unpin from top' : 'Pin to top'}
          >
            <Pin className={`w-3.5 h-3.5 ${entry.isPinned ? 'fill-indigo-400 rotate-45' : ''}`} />
          </button>

          <button
            onClick={() => onDelete?.(entry.id)}
            className="p-1.5 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-slate-800 transition-colors opacity-60 group-hover:opacity-100"
            title="Delete clipboard snippet"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Content Rendering */}
      {entry.contentType === 'url' && renderUrlPreview(entry.content)}
      {entry.contentType === 'code' && renderCodeBlock(entry.content)}
      {entry.contentType === 'text' && (
        <div className="bg-slate-950/60 rounded-lg p-3.5 border border-slate-800/60 mb-3">
          <p className="text-slate-100 text-sm whitespace-pre-wrap select-text font-sans leading-relaxed">
            {entry.content}
          </p>
        </div>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between text-xs text-slate-400 pt-1">
        <span className="flex items-center gap-1 text-slate-500">
          <Clock className="w-3 h-3" />
          {formatTime(entry.createdAt)}
        </span>

        {/* 1-Click Copy */}
        <button
          onClick={handleCopy}
          className={`flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-medium transition-all ${
            copied
              ? 'bg-emerald-500 text-white shadow-md shadow-emerald-500/20'
              : 'bg-slate-800 hover:bg-indigo-600 text-slate-200 hover:text-white border border-slate-700 hover:border-indigo-500'
          }`}
        >
          {copied ? (
            <>
              <Check className="w-3 h-3" /> Copied
            </>
          ) : (
            <>
              <Copy className="w-3 h-3" /> Copy
            </>
          )}
        </button>
      </div>
    </div>
  );
};
