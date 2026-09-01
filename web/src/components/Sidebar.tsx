import React from 'react';
import { 
  Layers, 
  Clipboard, 
  Search, 
  Monitor, 
  Filter, 
  LogOut, 
  ShieldCheck, 
  Activity, 
  Sparkles,
  Smartphone,
  Laptop
} from 'lucide-react';

interface SidebarProps {
  activeTab: 'typing' | 'clipboard';
  onTabChange: (tab: 'typing' | 'clipboard') => void;
  searchQuery: string;
  onSearchChange: (q: string) => void;
  selectedApp: string;
  onSelectApp: (app: string) => void;
  availableApps: { name: string; count: number }[];
  selectedDevice: string;
  onSelectDevice: (device: string) => void;
  availableDevices: string[];
  syncStatus: 'synced' | 'debouncing' | 'offline';
  userEmail?: string;
  userName?: string;
  onSignOut?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  onTabChange,
  searchQuery,
  onSearchChange,
  selectedApp,
  onSelectApp,
  availableApps,
  selectedDevice,
  onSelectDevice,
  availableDevices,
  syncStatus,
  userEmail = 'user@keyflow.dev',
  userName = 'Rama Krishna',
  onSignOut,
}) => {
  return (
    <aside className="w-72 md:w-80 bg-slate-950/90 backdrop-blur-xl border-r border-slate-800/80 flex flex-col h-screen select-none sticky top-0">
      {/* Brand Header */}
      <div className="p-5 border-b border-slate-800/80">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500 to-blue-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-500/25">
              KF
            </div>
            <div>
              <h1 className="text-base font-bold text-white tracking-tight">KeyFlow</h1>
              <p className="text-[11px] text-slate-400 font-medium">Session Recovery & Clipboard</p>
            </div>
          </div>

          {/* Real-time Status Badge */}
          <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-900 border border-slate-800 text-[11px] font-medium">
            <span
              className={`w-2 h-2 rounded-full ${
                syncStatus === 'synced'
                  ? 'bg-emerald-500 shadow-sm shadow-emerald-500/50'
                  : syncStatus === 'debouncing'
                  ? 'bg-amber-400 animate-ping'
                  : 'bg-rose-500'
              }`}
            />
            <span className="text-slate-300 capitalize">{syncStatus}</span>
          </div>
        </div>

        {/* Search Bar */}
        <div className="mt-4 relative">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Search sessions or snippets..."
            className="w-full pl-9 pr-3.5 py-2 bg-slate-900/90 border border-slate-800 focus:border-indigo-500/80 rounded-xl text-xs text-slate-200 placeholder-slate-500 outline-none transition-all"
          />
        </div>
      </div>

      {/* Main Nav Items (Dual Tab) */}
      <div className="px-4 py-3 space-y-1">
        <button
          onClick={() => onTabChange('typing')}
          className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
            activeTab === 'typing'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <span className="flex items-center gap-2.5">
            <Layers className="w-4 h-4" />
            Typing Stream
          </span>
          <span className="text-[10px] px-1.5 py-0.5 rounded bg-black/20 text-white font-mono">
            Sessions
          </span>
        </button>

        <button
          onClick={() => onTabChange('clipboard')}
          className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
            activeTab === 'clipboard'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
          }`}
        >
          <span className="flex items-center gap-2.5">
            <Clipboard className="w-4 h-4" />
            Clipboard History
          </span>
          <span className="text-[10px] px-1.5 py-0.5 rounded bg-black/20 text-white font-mono">
            Sync
          </span>
        </button>
      </div>

      {/* Filter Sections */}
      <div className="flex-1 overflow-y-auto px-4 py-2 space-y-5">
        {/* Device Filter */}
        <div>
          <div className="flex items-center justify-between text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-2">
            <span>Devices</span>
            <Monitor className="w-3 h-3 text-slate-500" />
          </div>
          <div className="space-y-1">
            <button
              onClick={() => onSelectDevice('')}
              className={`w-full flex items-center justify-between px-3 py-1.5 rounded-lg text-xs transition-colors ${
                selectedDevice === ''
                  ? 'bg-slate-800 text-indigo-400 font-medium'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
              }`}
            >
              <span>All Devices</span>
            </button>
            {availableDevices.map((dev) => (
              <button
                key={dev}
                onClick={() => onSelectDevice(dev)}
                className={`w-full flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs truncate transition-colors ${
                  selectedDevice === dev
                    ? 'bg-slate-800 text-indigo-400 font-medium'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
                }`}
              >
                {dev.toLowerCase().includes('phone') || dev.toLowerCase().includes('edge') ? (
                  <Smartphone className="w-3 h-3 text-slate-500 shrink-0" />
                ) : (
                  <Laptop className="w-3 h-3 text-slate-500 shrink-0" />
                )}
                <span className="truncate">{dev}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Application Filter */}
        <div>
          <div className="flex items-center justify-between text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-2">
            <span>Applications</span>
            <Filter className="w-3 h-3 text-slate-500" />
          </div>
          <div className="space-y-1">
            <button
              onClick={() => onSelectApp('')}
              className={`w-full flex items-center justify-between px-3 py-1.5 rounded-lg text-xs transition-colors ${
                selectedApp === ''
                  ? 'bg-slate-800 text-indigo-400 font-medium'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
              }`}
            >
              <span>All Apps</span>
            </button>
            {availableApps.map((app) => (
              <button
                key={app.name}
                onClick={() => onSelectApp(app.name)}
                className={`w-full flex items-center justify-between px-3 py-1.5 rounded-lg text-xs transition-colors ${
                  selectedApp === app.name
                    ? 'bg-slate-800 text-indigo-400 font-medium'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
                }`}
              >
                <span className="truncate">{app.name}</span>
                <span className="text-[10px] px-1.5 py-0.2 rounded bg-slate-800/80 text-slate-400 font-mono">
                  {app.count}
                </span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Footer User Profile & Sign Out */}
      <div className="p-4 border-t border-slate-800/80 bg-slate-950/90">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5 truncate">
            <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-indigo-400 shrink-0">
              {userName.substring(0, 2).toUpperCase()}
            </div>
            <div className="truncate">
              <p className="text-xs font-semibold text-white truncate">{userName}</p>
              <p className="text-[10px] text-slate-400 truncate">{userEmail}</p>
            </div>
          </div>

          <button
            onClick={onSignOut}
            className="p-2 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-slate-900 transition-colors"
            title="Sign Out"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );
};
