import React, { useState, useEffect, useRef } from 'react';
import { Play, Pause, RotateCcw, X, Clock, FileText, FastForward, Check, Copy } from 'lucide-react';
import type { TypingSession } from '../services/SessionAggregator';

interface ReplayDraftModalProps {
  session: TypingSession | null;
  isOpen: boolean;
  onClose: () => void;
}

export const ReplayDraftModal: React.FC<ReplayDraftModalProps> = ({
  session,
  isOpen,
  onClose,
}) => {
  if (!isOpen || !session) return null;

  const snapshots = session.draftHistory && session.draftHistory.length > 0
    ? session.draftHistory
    : [{ timestamp: session.startedAt, text: session.content, charCount: session.content.length }];

  const [currentIndex, setCurrentIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState<number>(1); // 1x, 2x, 4x
  const [copied, setCopied] = useState(false);
  const playIntervalRef = useRef<any>(null);

  // Stop playback on unmount or close
  useEffect(() => {
    return () => {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    };
  }, []);

  // Handle Playback Loop
  useEffect(() => {
    if (isPlaying) {
      const intervalMs = Math.max(100, Math.round(500 / playbackSpeed));
      playIntervalRef.current = setInterval(() => {
        setCurrentIndex((prev) => {
          if (prev >= snapshots.length - 1) {
            setIsPlaying(false);
            return prev;
          }
          return prev + 1;
        });
      }, intervalMs);
    } else {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    }

    return () => {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    };
  }, [isPlaying, playbackSpeed, snapshots.length]);

  const currentSnapshot = snapshots[currentIndex] || snapshots[snapshots.length - 1];

  const handleCopy = () => {
    navigator.clipboard.writeText(currentSnapshot.text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleReset = () => {
    setIsPlaying(false);
    setCurrentIndex(0);
  };

  const formatSnapshotTime = (isoString: string) => {
    try {
      return new Date(isoString).toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      });
    } catch {
      return isoString;
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="relative w-full max-w-2xl bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-900/90">
          <div className="flex items-center gap-2">
            <span className="p-2 rounded-lg bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
              <FileText className="w-4 h-4" />
            </span>
            <div>
              <h3 className="text-base font-semibold text-white flex items-center gap-2">
                Replay Draft History
                <span className="text-xs font-normal text-slate-400">
                  ({session.appName} • {session.deviceName})
                </span>
              </h3>
              <p className="text-xs text-slate-400">
                Step {currentIndex + 1} of {snapshots.length} • {formatSnapshotTime(currentSnapshot.timestamp)}
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Live Replay Text Canvas */}
        <div className="p-6 overflow-y-auto flex-1 bg-slate-950/80">
          <div className="min-h-[200px] p-4 rounded-xl bg-slate-900/90 border border-slate-800/80 font-sans text-sm md:text-base text-slate-100 leading-relaxed whitespace-pre-wrap select-text shadow-inner">
            {currentSnapshot.text}
            <span className="inline-block w-2 h-4 ml-0.5 bg-indigo-400 animate-pulse rounded-sm align-middle" />
          </div>
        </div>

        {/* Playback Controls & Slider */}
        <div className="p-6 border-t border-slate-800 bg-slate-900/95 space-y-4">
          {/* Timeline Slider */}
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs text-slate-400">
              <span>Start ({formatSnapshotTime(snapshots[0].timestamp)})</span>
              <span>{currentSnapshot.charCount} chars</span>
              <span>Final ({formatSnapshotTime(snapshots[snapshots.length - 1].timestamp)})</span>
            </div>
            <input
              type="range"
              min={0}
              max={snapshots.length - 1}
              value={currentIndex}
              onChange={(e) => {
                setIsPlaying(false);
                setCurrentIndex(parseInt(e.target.value, 10));
              }}
              className="w-full h-2 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-indigo-500 hover:accent-indigo-400"
            />
          </div>

          {/* Action Toolbar */}
          <div className="flex items-center justify-between flex-wrap gap-3">
            {/* Playback Buttons */}
            <div className="flex items-center gap-2">
              <button
                onClick={() => setIsPlaying(!isPlaying)}
                className={`flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-semibold shadow-lg transition-all ${
                  isPlaying
                    ? 'bg-amber-500 hover:bg-amber-400 text-slate-950'
                    : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-600/20'
                }`}
              >
                {isPlaying ? (
                  <>
                    <Pause className="w-3.5 h-3.5 fill-current" /> Pause
                  </>
                ) : (
                  <>
                    <Play className="w-3.5 h-3.5 fill-current" /> Play Replay
                  </>
                )}
              </button>

              <button
                onClick={handleReset}
                className="p-2 rounded-xl text-slate-400 hover:text-white bg-slate-800 hover:bg-slate-700 transition-colors"
                title="Restart from beginning"
              >
                <RotateCcw className="w-4 h-4" />
              </button>

              {/* Speed Switcher */}
              <div className="flex items-center bg-slate-800/80 rounded-xl p-0.5 border border-slate-700/50">
                {[1, 2, 4].map((speed) => (
                  <button
                    key={speed}
                    onClick={() => setPlaybackSpeed(speed)}
                    className={`px-2.5 py-1 text-xs font-medium rounded-lg transition-colors ${
                      playbackSpeed === speed
                        ? 'bg-indigo-600 text-white shadow-sm'
                        : 'text-slate-400 hover:text-white'
                    }`}
                  >
                    {speed}x
                  </button>
                ))}
              </div>
            </div>

            {/* Copy Current Snapshot */}
            <button
              onClick={handleCopy}
              className={`flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold transition-all ${
                copied
                  ? 'bg-emerald-500 text-white'
                  : 'bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700'
              }`}
            >
              {copied ? (
                <>
                  <Check className="w-3.5 h-3.5" /> Copied Current
                </>
              ) : (
                <>
                  <Copy className="w-3.5 h-3.5" /> Copy This Step
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
