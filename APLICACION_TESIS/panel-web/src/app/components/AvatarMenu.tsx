'use client';

import { useEffect, useRef, useState } from 'react';

export default function AvatarMenu({ username, onLogout }: { username: string; onLogout: () => void }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const initials = username ? username.slice(0, 2).toUpperCase() : 'AD';

  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-900 text-xs font-semibold text-white transition-opacity hover:opacity-90 dark:bg-slate-100 dark:text-slate-900"
      >
        {initials}
      </button>

      {open && (
        <div className="absolute right-0 top-11 z-50 w-52 overflow-hidden rounded-lg border border-slate-200 bg-white py-1 shadow-lg dark:border-slate-700 dark:bg-slate-900">
          <div className="border-b border-slate-100 px-3 py-2 dark:border-slate-800">
            <p className="text-sm font-semibold text-slate-900 dark:text-slate-100">{username || 'Administrador'}</p>
            <p className="text-xs text-slate-400">Cuenta administrativa</p>
          </div>
          <button
            type="button"
            onClick={onLogout}
            className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-red-600 transition-colors hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-950"
          >
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
            </svg>
            Cerrar sesión
          </button>
        </div>
      )}
    </div>
  );
}