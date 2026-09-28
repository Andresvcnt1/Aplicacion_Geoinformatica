'use client';

import { JSX, useEffect, useRef, useState } from 'react';

interface NavItem {
  id: string;
  label: string;
  badge?: number;
}

const ITEMS: NavItem[] = [
  { id: 'panel',      label: 'Panel de Control' },
  { id: 'mapa',       label: 'Mapa' },
  { id: 'parroquias', label: 'Parroquias' },
  { id: 'reportes',   label: 'Reportes' },
];

const ICONS: Record<string, JSX.Element> = {
  panel: (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="9" rx="1" />
      <rect x="14" y="3" width="7" height="5" rx="1" />
      <rect x="14" y="12" width="7" height="9" rx="1" />
      <rect x="3" y="16" width="7" height="5" rx="1" />
    </svg>
  ),
  mapa: (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 20 4 18V6l5 2m0 12 6-2m-6 2V8m6 10 5 2V8l-5-2m0 14V6m0 0L9 8" />
    </svg>
  ),
  parroquias: (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 21s-7-6.1-7-11.5a7 7 0 0 1 14 0C19 14.9 12 21 12 21Z" />
      <circle cx="12" cy="9.5" r="2.5" />
    </svg>
  ),
  reportes: (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 4h10v16H9M9 4 5 8v12h4M9 4v16" />
    </svg>
  ),
};

// Tooltip que aparece al hover cuando el sidebar está colapsado
function Tooltip({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="group relative flex">
      {children}
      <div className="pointer-events-none absolute left-full top-1/2 z-50 ml-3 -translate-y-1/2 whitespace-nowrap rounded-md bg-slate-900 px-2.5 py-1.5 text-xs font-medium text-white opacity-0 shadow-lg transition-opacity duration-150 group-hover:opacity-100 dark:bg-slate-700">
        {label}
        <div className="absolute right-full top-1/2 -translate-y-1/2 border-4 border-transparent border-r-slate-900 dark:border-r-slate-700" />
      </div>
    </div>
  );
}

export default function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const [active, setActive] = useState('panel');
  const observerRef = useRef<IntersectionObserver | null>(null);

  useEffect(() => {
    const sections = ITEMS.map((item) => document.getElementById(item.id)).filter(
      (el): el is HTMLElement => el !== null
    );
    observerRef.current = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) setActive(entry.target.id);
        });
      },
      { rootMargin: '-20% 0px -70% 0px' }
    );
    sections.forEach((el) => observerRef.current?.observe(el));
    return () => observerRef.current?.disconnect();
  }, []);

  const goTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  return (
    <aside
      className={`sticky top-0 flex h-screen shrink-0 flex-col bg-slate-950 transition-all duration-300 ease-in-out dark:bg-slate-950 ${
        collapsed ? 'w-[68px]' : 'w-[220px]'
      }`}
    >
      {/* ── Logo / Brand ───────────────────────────────────────────────── */}
      <div
        className={`flex items-center border-b border-slate-800 ${
          collapsed ? 'justify-center px-0 py-4' : 'justify-between px-4 py-4'
        }`}
      >
        {/* Ícono de mapa con dot verde */}
        <div className="relative flex shrink-0 items-center justify-center">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-500/20">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#34d399" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7Z" />
              <circle cx="12" cy="9" r="2.5" />
            </svg>
          </div>
          {/* dot de estado activo */}
          <span className="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-emerald-400 ring-2 ring-slate-950" />
        </div>

        {!collapsed && (
          <div className="ml-2.5 min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-white">GeoIncidencias</p>
            <p className="text-[11px] text-slate-400">Municipio de Loja</p>
          </div>
        )}

        {/* Botón colapsar — solo visible en modo expandido */}
        {!collapsed && (
          <button
            type="button"
            onClick={() => setCollapsed(true)}
            aria-label="Colapsar menú"
            className="ml-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-slate-500 transition-colors hover:bg-slate-800 hover:text-slate-200"
          >
            {/* chevron izquierda */}
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="m15 18-6-6 6-6" />
            </svg>
          </button>
        )}
      </div>

      {/* ── Botón expandir (solo colapsado) ─────────────────────────────── */}
      {collapsed && (
        <div className="flex justify-center border-b border-slate-800 py-2">
          <button
            type="button"
            onClick={() => setCollapsed(false)}
            aria-label="Expandir menú"
            className="flex h-7 w-7 items-center justify-center rounded-md text-slate-500 transition-colors hover:bg-slate-800 hover:text-slate-200"
          >
            {/* chevron derecha */}
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="m9 18 6-6-6-6" />
            </svg>
          </button>
        </div>
      )}

      {/* ── Navegación ───────────────────────────────────────────────────── */}
      <nav className="flex-1 space-y-0.5 px-2 py-4">
        {!collapsed && (
          <p className="mb-2 px-2 text-[10px] font-semibold uppercase tracking-widest text-slate-500">
            General
          </p>
        )}

        {ITEMS.map((item) => {
          const isActive = active === item.id;
          const btn = (
            <button
              key={item.id}
              type="button"
              onClick={() => goTo(item.id)}
              title={collapsed ? item.label : undefined}
              className={`relative flex w-full items-center rounded-lg px-2.5 py-2.5 text-sm font-medium transition-all duration-150 ${
                collapsed ? 'justify-center' : 'gap-3'
              } ${
                isActive
                  ? 'bg-emerald-500/15 text-emerald-400'
                  : 'text-slate-400 hover:bg-slate-800/70 hover:text-slate-100'
              }`}
            >
              {/* barra izquierda activo */}
              {isActive && !collapsed && (
                <span className="absolute left-0 top-1/2 h-5 w-0.5 -translate-y-1/2 rounded-full bg-emerald-400" />
              )}

              <span className={`shrink-0 ${isActive ? 'text-emerald-400' : ''}`}>
                {ICONS[item.id]}
              </span>

              {!collapsed && (
                <span className="flex-1 text-left">{item.label}</span>
              )}

              {/* badge opcional (ej: reportes nuevos) */}
              {!collapsed && item.badge != null && item.badge > 0 && (
                <span className="rounded-full bg-emerald-500 px-1.5 py-0.5 text-[10px] font-semibold leading-none text-white">
                  {item.badge}
                </span>
              )}
            </button>
          );

          // Wrap en tooltip solo cuando está colapsado
          return collapsed ? (
            <Tooltip key={item.id} label={item.label}>
              {btn}
            </Tooltip>
          ) : (
            <div key={item.id}>{btn}</div>
          );
        })}
      </nav>

      {/* ── Divider ──────────────────────────────────────────────────────── */}
      <div className="mx-3 border-t border-slate-800" />

      {/* ── Footer / versión ─────────────────────────────────────────────── */}
      <div
        className={`flex items-center py-4 ${
          collapsed ? 'justify-center px-0' : 'gap-2.5 px-3'
        }`}
      >
        {/* ícono escudo/sistema */}
        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-slate-800 text-slate-400">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
          </svg>
        </div>

        {!collapsed && (
          <div className="min-w-0">
            <p className="truncate text-[11px] font-medium text-slate-300">Sistema GIS</p>
            <p className="text-[10px] text-slate-500">v1.0 · Tesis 2026</p>
          </div>
        )}
      </div>
    </aside>
  );
}