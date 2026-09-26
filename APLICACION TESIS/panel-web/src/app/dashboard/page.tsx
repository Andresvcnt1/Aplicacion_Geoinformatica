'use client';

import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import axios from 'axios';
import api from '@/lib/api';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts';

interface Incidencia {
  id: number;
  categoria: string;
  descripcion: string;
  estado: string;
  fecha_creacion?: string;
  usuario_nombre?: string;
  foto?: string;
  geometry?: { type: string; coordinates: [number, number] };
  ubicacion?: { type: string; coordinates: [number, number] } | string;
}

const MapaIncidencias = dynamic(() => import('../components/MapaIncidencias'), {
  ssr: false,
  loading: () => <div className="h-[440px] animate-pulse rounded-lg bg-slate-100 dark:bg-slate-800" />,
});

const CATEGORIA_META: Record<string, { label: string; color: string }> = {
  AGUA: { label: 'Agua', color: '#0EA5E9' },
  VIAL: { label: 'Vial', color: '#7C3AED' },
  LUZ: { label: 'Alumbrado', color: '#EAB308' },
  OTRO: { label: 'Otro', color: '#64748B' },
};

const ESTADO_BADGE: Record<string, string> = {
  Recibido: 'bg-red-50 text-red-700 border-red-200 dark:bg-red-950 dark:text-red-300 dark:border-red-900',
  'En proceso': 'bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950 dark:text-orange-300 dark:border-orange-900',
  Solucionado: 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300 dark:border-emerald-900',
};

const ESTADO_ROW_BORDER: Record<string, string> = {
  Recibido: 'border-l-red-400',
  'En proceso': 'border-l-orange-400',
  Solucionado: 'border-l-emerald-400',
};

function useCountUp(target: number, duration = 900) {
  const [value, setValue] = useState(0);
  useEffect(() => {
    let start: number | null = null;
    let frame: number;
    const step = (timestamp: number) => {
      if (start === null) start = timestamp;
      const progress = Math.min((timestamp - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setValue(Math.round(eased * target));
      if (progress < 1) frame = requestAnimationFrame(step);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
  }, [target, duration]);
  return value;
}

function KpiIcon({ kind, color }: { kind: 'total' | 'recibido' | 'proceso' | 'solucionado'; color: string }) {
  const common = { width: 20, height: 20, stroke: color, fill: 'none', strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const };
  if (kind === 'total') return <svg viewBox="0 0 24 24" {...common}><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M3 9h18M8 4v3M16 4v3" /></svg>;
  if (kind === 'recibido') return <svg viewBox="0 0 24 24" {...common}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>;
  if (kind === 'proceso') return <svg viewBox="0 0 24 24" {...common}><path d="M21 12a9 9 0 1 1-3.5-7.1M21 4v5h-5" /></svg>;
  return <svg viewBox="0 0 24 24" {...common}><path d="M20 6 9 17l-5-5" /></svg>;
}

function ThemeToggle() {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem('theme');
    const isDark = saved === 'dark';
    setDark(isDark);
    document.documentElement.classList.toggle('dark', isDark);
  }, []);

  const toggle = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle('dark', next);
    localStorage.setItem('theme', next ? 'dark' : 'light');
  };

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={dark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
      className="flex h-9 w-9 items-center justify-center rounded-full border border-slate-300 text-slate-600 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-800"
    >
      {dark ? (
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
        </svg>
      )}
    </button>
  );
}

function KpiStat({
  label,
  value,
  accent,
  tint,
  darkTint,
  kind,
  loading,
  delay,
}: {
  label: string;
  value: number;
  accent: string;
  tint: string;
  darkTint: string;
  kind: 'total' | 'recibido' | 'proceso' | 'solucionado';
  loading: boolean;
  delay: number;
}) {
  const animated = useCountUp(value);
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    setIsDark(document.documentElement.classList.contains('dark'));
    const observer = new MutationObserver(() => {
      setIsDark(document.documentElement.classList.contains('dark'));
    });
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
    return () => observer.disconnect();
  }, []);

  return (
    <div className="animate-enter bg-white px-6 py-5 dark:bg-slate-900" style={{ animationDelay: `${delay}ms` }}>
      <div className="flex items-center justify-between">
        <p className="text-sm text-slate-500 dark:text-slate-400">{label}</p>
        <div
          className="flex h-9 w-9 items-center justify-center rounded-full"
          style={{ backgroundColor: isDark ? darkTint : tint }}
        >
          <KpiIcon kind={kind} color={accent} />
        </div>
      </div>
      <p className="mt-3 font-display text-3xl font-semibold text-slate-900 dark:text-slate-50">{loading ? '—' : animated}</p>
    </div>
  );
}

export default function DashboardPage() {
  const [incidencias, setIncidencias] = useState<Incidencia[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const router = useRouter();

  useEffect(() => {
    if (!localStorage.getItem('access_token')) {
      router.replace('/login');
      return;
    }

    const cargarIncidencias = async () => {
      try {
        await api.get('/admin/access/');
        const response = await api.get('/reportes/');
        const payload = response.data;
        const rows = Array.isArray(payload) ? payload : payload.results;
        setIncidencias(Array.isArray(rows) ? rows : []);
      } catch (requestError) {
        if (axios.isAxiosError(requestError) && [401, 403].includes(requestError.response?.status ?? 0)) {
          localStorage.removeItem('access_token');
          localStorage.removeItem('refresh_token');
          router.replace('/login');
          return;
        }
        setError('No fue posible cargar las incidencias. Intenta actualizar la página.');
      } finally {
        setLoading(false);
      }
    };

    void cargarIncidencias();
  }, [router]);

  const cerrarSesion = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    router.replace('/login');
  };

  const recibidas = incidencias.filter((item) => item.estado.toLowerCase() === 'recibido').length;
  const enProceso = incidencias.filter((item) => item.estado.toLowerCase() === 'en proceso').length;
  const solucionadas = incidencias.filter((item) => item.estado.toLowerCase() === 'solucionado').length;

  const categoriaData = Object.keys(CATEGORIA_META).map((key) => ({
    categoria: CATEGORIA_META[key].label,
    total: incidencias.filter((i) => i.categoria === key).length,
    color: CATEGORIA_META[key].color,
  }));

  return (
    <main className="min-h-screen bg-[#F6F7F5] text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <header className="relative border-b border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900">
        <div
          className="absolute inset-x-0 top-0 h-1"
          style={{ background: 'linear-gradient(90deg, #059669 0%, #0EA5E9 33%, #7C3AED 66%, #EAB308 100%)' }}
        />
        <div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-5 sm:px-8">
          <div>
            <p className="text-sm font-medium text-emerald-700 dark:text-emerald-400">GeoIncidencias Loja</p>
            <h1 className="mt-1 font-display text-2xl font-semibold tracking-tight">Panel administrativo</h1>
          </div>
          <div className="flex items-center gap-3">
            <ThemeToggle />
            <button
              type="button"
              onClick={cerrarSesion}
              className="rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:text-slate-200 dark:hover:bg-slate-800"
            >
              Cerrar sesión
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-7xl px-5 py-8 sm:px-8">
        <section
          aria-label="Resumen de incidencias"
          className="grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-slate-200 bg-slate-200 shadow-sm dark:border-slate-800 dark:bg-slate-800 sm:grid-cols-4"
        >
          <KpiStat label="Total reportadas" value={incidencias.length} accent="#334155" tint="#F1F5F9" darkTint="#1E293B" kind="total" loading={loading} delay={0} />
          <KpiStat label="Recibidas" value={recibidas} accent="#ef4444" tint="#FEF2F2" darkTint="#450A0A" kind="recibido" loading={loading} delay={60} />
          <KpiStat label="En proceso" value={enProceso} accent="#f97316" tint="#FFF7ED" darkTint="#431407" kind="proceso" loading={loading} delay={120} />
          <KpiStat label="Solucionadas" value={solucionadas} accent="#22c55e" tint="#F0FDF4" darkTint="#052E16" kind="solucionado" loading={loading} delay={180} />
        </section>

        {error && (
          <p role="alert" className="mt-6 border-l-4 border-red-600 bg-red-50 px-4 py-3 text-sm text-red-800 dark:bg-red-950 dark:text-red-300">
            {error}
          </p>
        )}

        <section className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="animate-enter lg:col-span-2" style={{ animationDelay: '220ms' }}>
            <div className="mb-4 flex items-end justify-between gap-4">
              <div>
                <h2 className="font-display text-lg font-semibold">Mapa de incidencias</h2>
                <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">Reportes ciudadanos registrados en Loja</p>
              </div>
              <button
                type="button"
                onClick={() => window.location.reload()}
                className="shrink-0 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
              >
                Actualizar
              </button>
            </div>
            <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
              <MapaIncidencias data={incidencias} />
              <div className="flex flex-wrap items-center gap-4 border-t border-slate-100 px-4 py-3 text-xs text-slate-500 dark:border-slate-800 dark:text-slate-400">
                <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full bg-red-500" /> Recibido</span>
                <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full bg-orange-500" /> En proceso</span>
                <span className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full bg-emerald-500" /> Solucionado</span>
              </div>
            </div>
          </div>

          <div className="animate-enter" style={{ animationDelay: '280ms' }}>
            <h2 className="font-display text-lg font-semibold">Reportes por categoría</h2>
            <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">Distribución del total registrado</p>
            <div className="mt-4 rounded-lg border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
              <ResponsiveContainer width="100%" height={280}>
                <BarChart data={categoriaData} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
                  <XAxis dataKey="categoria" tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={{ stroke: '#334155' }} tickLine={false} />
                  <YAxis allowDecimals={false} tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
                  <Tooltip cursor={{ fill: 'rgba(148,163,184,0.08)' }} contentStyle={{ borderRadius: 8, border: '1px solid #334155', fontSize: 13, backgroundColor: '#0F172A', color: '#F1F5F9' }} />
                  <Bar dataKey="total" radius={[6, 6, 0, 0]} maxBarSize={48}>
                    {categoriaData.map((entry) => (
                      <Cell key={entry.categoria} fill={entry.color} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
              <div className="mt-2 flex flex-wrap gap-3 border-t border-slate-100 pt-3 text-xs text-slate-500 dark:border-slate-800 dark:text-slate-400">
                {categoriaData.map((c) => (
                  <span key={c.categoria} className="flex items-center gap-1.5">
                    <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: c.color }} />
                    {c.categoria}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="mt-8 animate-enter" style={{ animationDelay: '340ms' }}>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-display text-lg font-semibold">Reportes recientes</h2>
            <span className="text-sm text-slate-500 dark:text-slate-400">{incidencias.length} registros</span>
          </div>
          <div className="overflow-x-auto rounded-lg border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
            <table className="w-full min-w-[640px] border-collapse text-left text-sm">
              <thead className="border-b border-slate-200 bg-slate-50 text-xs text-slate-500 dark:border-slate-800 dark:bg-slate-800/50 dark:text-slate-400">
                <tr>
                  <th className="px-4 py-3 font-medium">Categoría</th>
                  <th className="px-4 py-3 font-medium">Descripción</th>
                  <th className="px-4 py-3 font-medium">Reportado por</th>
                  <th className="px-4 py-3 font-medium">Estado</th>
                  <th className="px-4 py-3 font-medium">Fecha</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                {loading ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-slate-500 dark:text-slate-400">Cargando reportes...</td>
                  </tr>
                ) : incidencias.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-slate-500 dark:text-slate-400">Aún no hay incidencias registradas.</td>
                  </tr>
                ) : (
                  incidencias.slice(0, 10).map((incidencia) => {
                    const meta = CATEGORIA_META[incidencia.categoria];
                    return (
                      <tr
                        key={incidencia.id}
                        className={`border-l-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/50 ${ESTADO_ROW_BORDER[incidencia.estado] || 'border-l-slate-200'}`}
                      >
                        <td className="px-4 py-3 font-medium">
                          <span className="inline-flex items-center gap-2">
                            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: meta?.color || '#94A3B8' }} />
                            {meta?.label || incidencia.categoria}
                          </span>
                        </td>
                        <td className="max-w-xs truncate px-4 py-3 text-slate-600 dark:text-slate-300">{incidencia.descripcion || 'Sin descripción'}</td>
                        <td className="px-4 py-3 text-slate-600 dark:text-slate-300">{incidencia.usuario_nombre || 'Anónimo'}</td>
                        <td className="px-4 py-3">
                          <span
                            className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${
                              ESTADO_BADGE[incidencia.estado] || 'bg-slate-50 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700'
                            }`}
                          >
                            {incidencia.estado}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-slate-600 dark:text-slate-300">
                          {incidencia.fecha_creacion ? new Date(incidencia.fecha_creacion).toLocaleDateString('es-EC') : '—'}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
  );
}