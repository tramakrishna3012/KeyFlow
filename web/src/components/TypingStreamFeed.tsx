import React from 'react';
import { Layers, RefreshCw, Sparkles, Filter } from 'lucide-react';
import { TypingHistoryCard } from './TypingHistoryCard';
import type { TypingSession } from '../services/SessionAggregator';

interface TypingStreamFeedProps {
  sessions: TypingSession[];
  isLoading: boolean;
  onRefresh: () => void;
  onToggleFavorite: (id: string) => void;
  onReplayDraft: (session: TypingSession) => void;
  onDelete: (id: string) => void;
  selectedApp?: string;
  selectedDevice?: string;
}

export const TypingStreamFeed: React.FC<TypingStreamFeedProps> = ({
  sessions,
  isLoading,
  onRefresh,
  onToggleFavorite,
  onReplayDraft,
  onDelete,
  selectedApp,
  selectedDevice,
}) => {
  return (
    <div className="flex-1 max-w-4xl mx-auto w-full px-4 md:px-8 py-6">
      {/* Feed Header & Controls */}
      <div className="flex items-center justify-between gap-4 mb-6 pb-4 border-b border-slate-800">
        <div>
          <h2 className="text-xl font-bold text-white flex items-center gap-2">
            <Layers className="w-5 h-5 text-indigo-400" />
            Session Typing Stream
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Paragraph-aggregated inputs debounced every 2.5s • Showing {sessions.length} sessions
            {selectedApp && <span className="text-indigo-400 font-medium"> in {selectedApp}</span>}
            {selectedDevice && <span className="text-slate-300 font-medium"> on {selectedDevice}</span>}
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

      {/* Feed Content */}
      {isLoading && sessions.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-slate-500">
          <RefreshCw className="w-8 h-8 animate-spin text-indigo-500 mb-3" />
          <p className="text-sm">Loading typing sessions...</p>
        </div>
      ) : sessions.length === 0 ? (
        <div className="text-center py-20 px-4 bg-slate-900/40 rounded-2xl border border-dashed border-slate-800">
          <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center mx-auto mb-3">
            <Sparkles className="w-6 h-6" />
          </div>
          <h3 className="text-base font-semibold text-white mb-1">No typing sessions yet</h3>
          <p className="text-xs text-slate-400 max-w-md mx-auto">
            Start typing in any application on your connected mobile or desktop devices. KeyFlow will automatically group your keystrokes into clean paragraphs.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {sessions.map((session) => (
            <TypingHistoryCard
              key={session.id}
              session={session}
              onToggleFavorite={onToggleFavorite}
              onReplayDraft={onReplayDraft}
              onDelete={onDelete}
            />
          ))}
        </div>
      )}
    </div>
  );
};
