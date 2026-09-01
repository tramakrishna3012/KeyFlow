import React, { useState } from 'react';
import { Clipboard, RefreshCw, Sparkles, Filter, Code, Link as LinkIcon, FileText } from 'lucide-react';
import { ClipboardHistoryCard } from './ClipboardHistoryCard';
import type { ClipboardEntry } from '../services/SessionAggregator';

interface ClipboardHistoryFeedProps {
  entries: ClipboardEntry[];
  isLoading: boolean;
  onRefresh: () => void;
  onTogglePin: (id: string) => void;
  onDelete: (id: string) => void;
}

export const ClipboardHistoryFeed: React.FC<ClipboardHistoryFeedProps> = ({
  entries,
  isLoading,
  onRefresh,
  onTogglePin,
  onDelete,
}) => {
  const [selectedType, setSelectedType] = useState<'all' | 'text' | 'url' | 'code'>('all');

  const filteredEntries = entries.filter((e) => {
    if (selectedType === 'all') return true;
    return e.contentType === selectedType;
  });

  return (
    <div className="flex-1 max-w-4xl mx-auto w-full px-4 md:px-8 py-6">
      {/* Header & Controls */}
      <div className="flex items-center justify-between gap-4 mb-6 pb-4 border-b border-slate-800">
        <div>
          <h2 className="text-xl font-bold text-white flex items-center gap-2">
            <Clipboard className="w-5 h-5 text-indigo-400" />
            Synchronized Clipboard Feed
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Real-time copied text, syntax-highlighted code, and rich URL previews across all devices.
          </p>
        </div>

        <button
          onClick={onRefresh}
          disabled={isLoading}
          className="flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-200 hover:text-white transition-all shadow-sm active:scale-95 disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 text-indigo-400 ${isLoading ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      {/* Content Type Filter Pills */}
      <div className="flex items-center gap-2 mb-5 overflow-x-auto pb-1">
        <button
          onClick={() => setSelectedType('all')}
          className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
            selectedType === 'all'
              ? 'bg-indigo-600 text-white'
              : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
          }`}
        >
          All Items ({entries.length})
        </button>

        <button
          onClick={() => setSelectedType('code')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
            selectedType === 'code'
              ? 'bg-purple-600 text-white'
              : 'bg-slate-900 text-slate-400 hover:text-purple-300 border border-slate-800'
          }`}
        >
          <Code className="w-3.5 h-3.5" />
          Code Blocks ({entries.filter((e) => e.contentType === 'code').length})
        </button>

        <button
          onClick={() => setSelectedType('url')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
            selectedType === 'url'
              ? 'bg-sky-600 text-white'
              : 'bg-slate-900 text-slate-400 hover:text-sky-300 border border-slate-800'
          }`}
        >
          <LinkIcon className="w-3.5 h-3.5" />
          URLs & Links ({entries.filter((e) => e.contentType === 'url').length})
        </button>

        <button
          onClick={() => setSelectedType('text')}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
            selectedType === 'text'
              ? 'bg-emerald-600 text-white'
              : 'bg-slate-900 text-slate-400 hover:text-emerald-300 border border-slate-800'
          }`}
        >
          <FileText className="w-3.5 h-3.5" />
          Text ({entries.filter((e) => e.contentType === 'text').length})
        </button>
      </div>

      {/* Feed List */}
      {isLoading && entries.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-500">
          <RefreshCw className="w-8 h-8 animate-spin text-indigo-500 mb-3" />
          <p className="text-sm">Loading clipboard history...</p>
        </div>
      ) : filteredEntries.length === 0 ? (
        <div className="text-center py-20 px-4 bg-slate-900/40 rounded-2xl border border-dashed border-slate-800">
          <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center mx-auto mb-3">
            <Clipboard className="w-6 h-6" />
          </div>
          <h3 className="text-base font-semibold text-white mb-1">No clipboard items found</h3>
          <p className="text-xs text-slate-400 max-w-md mx-auto">
            Copy any text, link, or code snippet on your mobile device or desktop. It will synchronize here automatically.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredEntries.map((entry) => (
            <ClipboardHistoryCard
              key={entry.id}
              entry={entry}
              onTogglePin={onTogglePin}
              onDelete={onDelete}
            />
          ))}
        </div>
      )}
    </div>
  );
};
