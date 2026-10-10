'use client';

import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import axios from 'axios';
import api from '@/lib/api';
import { ESTADOS, claseBadge, etiquetaEstado, type EstadoValor } from '@/lib/estados';
import ReporteModal from '../components/ReporteModal';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import ReporteParroquias from '../components/ReporteParroquias';
import Sidebar from '../components/Sidebar';
import AvatarMenu from '../components/AvatarMenu';

interface Incidencia {
  id: number;
  categoria: string;
  descripcion: string;
  estado: string;
  estado_display?: string;
  prioritaria?: boolean;
  anonimo?: boolean;
  fecha_creacion?: string;
  usuario_nombre?: string;
  foto_url?: string;
  foto?: string;
  geometry?: { type: string; coordinates: [number, number] };
  ubicacion?: { type: string; coordinates: [number, number] } | string;
}

const MapaIncidencias = dynamic(() => import('../components/MapaIncidencias'), {
  ssr: false,
  loading: () => <div className="h-[440px] animate-pulse rounded-lg bg-slate-100 dark:bg-slate-800" />,
});

const CATEGORIA_META: Record<string, { label: string; color: string }> = {
  AGUA: { label: 'Agua',      color: '#0EA5E9' },
  VIAL: { label: 'Vial',      color: '#7C3AED' },
  LUZ:  { label: 'Alumbrado', color: '#EAB308' },
  OTRO: { label: 'Otro',      color: '#64748B' },
};

const MESES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

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
  if (kind === 'total')    return <svg viewBox="0 0 24 24" {...common}><rect x="3" y="4" width="18" height="16" rx="2" /><path d="M3 9h18M8 4v3M16 4v3" /></svg>;
  if (kind === 'recibido') return <svg viewBox="0 0 24 24" {...common}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>;
  if (kind === 'proceso')  return <svg viewBox="0 0 24 24" {...common}><path d="M21 12a9 9 0 1 1-3.5-7.1M21 4v5h-5" /></svg>;
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
  label, value, accent, tint, darkTint, kind, loading, delay,
}: {
  label: string; value: number; accent: string; tint: string; darkTint: string;
  kind: 'total' | 'recibido' | 'proceso' | 'solucionado'; loading: boolean; delay: number;
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
    <div className="bg-white px-6 py-5 dark:bg-slate-900" style={{ animationDelay: `${delay}ms` }}>
      <div className="flex items-center justify-between">
        <p className="text-sm text-slate-500 dark:text-slate-400">{label}</p>
        <div className="flex h-9 w-9 items-center justify-center rounded-full" style={{ backgroundColor: isDark ? darkTint : tint }}>
          <KpiIcon kind={kind} color={accent} />
        </div>
      </div>
      <p className="mt-3 font-display text-3xl font-semibold text-slate-900 dark:text-slate-50">
        {loading ? '—' : animated}
      </p>
    </div>
  );
}

export default function DashboardPage() {
  const [incidencias, setIncidencias]                   = useState<Incidencia[]>([]);
  const [reporteSeleccionado, setReporteSeleccionado]   = useState<Incidencia | null>(null);
  const [loading, setLoading]                           = useState(true);
  const [error, setError]                               = useState('');
  const [filtroEstado, setFiltroEstado]                 = useState<'Todos' | EstadoValor>('Todos');
  const [adminUsername, setAdminUsername]               = useState('');
  const [soloPrioritarios, setSoloPrioritarios]       = useState(false);
  const hoy = new Date();
  const [mesInforme, setMesInforme]                     = useState(hoy.getMonth() + 1);
  const [anioInforme, setAnioInforme]                   = useState(hoy.getFullYear());
  const [generandoInforme, setGenerandoInforme]         = useState(false);
  const [errorInforme, setErrorInforme]                 = useState('');
  const router = useRouter();

  const reportesFiltrados = incidencias.filter(
    (i) =>
      (filtroEstado === 'Todos' || i.estado === filtroEstado) &&
      (!soloPrioritarios || i.prioritaria === true),
  );

  useEffect(() => {
    if (!localStorage.getItem('access_token')) { router.replace('/login'); return; }
    const cargar = async () => {
      try {
        const accessRes = await api.get('/admin/access/');
        setAdminUsername(accessRes.data.username || '');
        const res  = await api.get('/reportes/');
        const data = res.data;
        const rows = Array.isArray(data) ? data : data.results;
        setIncidencias(Array.isArray(rows) ? rows : []);
      } catch (err) {
        if (axios.isAxiosError(err) && [401, 403].includes(err.response?.status ?? 0)) {
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
    void cargar();
  }, [router]);

  const actualizarEstadoLocal = (id: number, nuevoEstado: string) => {
    setIncidencias((prev) => prev.map((inc) => (inc.id === id ? { ...inc, estado: nuevoEstado } : inc)));
    setReporteSeleccionado((prev) => prev?.id === id ? { ...prev, estado: nuevoEstado } : prev);
  };

  const exportarCSV = () => {
    const headers = ['ID','Categoría','Descripción','Reportado por','Estado','Fecha','Prioridad','Anónimo'];
    const rows = reportesFiltrados.map((inc) => [
      inc.id,
      CATEGORIA_META[inc.categoria]?.label || inc.categoria,
      (inc.descripcion || 'Sin descripción').replace(/"/g, '""'),
      inc.usuario_nombre || 'Anónimo',
      etiquetaEstado(inc.estado),
      inc.fecha_creacion ? new Date(inc.fecha_creacion).toLocaleString('es-EC') : '',
      inc.prioritaria ? 'VIP' : 'Normal',
      inc.anonimo ? 'Sí' : 'No',
    ]);
    const csv  = [headers, ...rows].map((r) => r.map((c) => `"${c}"`).join(',')).join('\n');
    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a'); a.href = url;
    a.download = `reportes_${new Date().toISOString().slice(0,10)}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  // PDF rápido de la lista que estás viendo (generado en el navegador)
  const exportarPDF = async () => {
    const { default: jsPDF }     = await import('jspdf');
    const { default: autoTable } = await import('jspdf-autotable');
    const doc = new jsPDF();
    doc.setFontSize(14);
    doc.text('GeoIncidencias Loja — Reporte de incidencias', 14, 16);
    doc.setFontSize(9); doc.setTextColor(100);
    doc.text(`Generado: ${new Date().toLocaleString('es-EC')} · Filtro: ${filtroEstado === 'Todos' ? 'Todos' : etiquetaEstado(filtroEstado)}`, 14, 22);
    autoTable(doc, {
      startY: 28,
      head: [['ID','Categoría','Descripción','Reportado por','Estado','Fecha']],
      body: reportesFiltrados.map((inc) => [
        inc.id, CATEGORIA_META[inc.categoria]?.label || inc.categoria,
        inc.descripcion || 'Sin descripción', inc.usuario_nombre || 'Anónimo',
        etiquetaEstado(inc.estado), inc.fecha_creacion ? new Date(inc.fecha_creacion).toLocaleDateString('es-EC') : '—',
      ]),
      styles: { fontSize: 8 },
      headStyles: { fillColor: [51, 65, 85] },
    });
    doc.save(`reportes_${new Date().toISOString().slice(0,10)}.pdf`);
  };

  // Informe mensual consolidado (RF014): lo genera el servidor; se envía el token en el header
  const descargarInformeMensual = async () => {
    setGenerandoInforme(true);
    setErrorInforme('');
    try {
      const res = await api.get('/informe-mensual/', {
        params: { anio: anioInforme, mes: mesInforme },
        responseType: 'blob',
      });
      const url = URL.createObjectURL(new Blob([res.data], { type: 'application/pdf' }));
      const a = document.createElement('a');
      a.href = url;
      a.download = `informe_incidencias_${anioInforme}_${String(mesInforme).padStart(2, '0')}.pdf`;
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      setErrorInforme('No se pudo generar el informe mensual. Verifica el mes y el año e intenta de nuevo.');
    } finally {
      setGenerandoInforme(false);
    }
  };

  const cerrarSesion = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    router.replace('/login');
  };

  const contar = (...valores: EstadoValor[]) =>
    incidencias.filter((i) => valores.includes(i.estado as EstadoValor)).length;

  const recibidas  = contar('recibido');
  const enGestion  = contar('en_revision', 'en_proceso');
  const resueltas  = contar('subsanado', 'cerrado');

  const prioritarias = incidencias.filter((i) => i.prioritaria === true).length;

  const tabs: { key: 'Todos' | EstadoValor; label: string; count: number; dot: string }[] = [
    { key: 'Todos', label: 'Todos', count: incidencias.length, dot: '#334155' },
    ...ESTADOS.map((e) => ({ key: e.value, label: e.label, count: contar(e.value), dot: e.color })),
  ];

  const categoriaData = Object.keys(CATEGORIA_META).map((key) => ({
    categoria: CATEGORIA_META[key].label,
    total:     incidencias.filter((i) => i.categoria === key).length,
    color:     CATEGORIA_META[key].color,
  }));

  return (
    <div className="flex min-h-screen bg-[#F6F7F5] dark:bg-slate-950">
      <Sidebar />

      <main className="flex min-w-0 flex-1 flex-col text-slate-900 dark:text-slate-100">

        {/* ── Header ─────────────────────────────────────────────────────── */}
        <header className="relative shrink-0 border-b border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900">
          <div
            className="absolute inset-x-0 top-0 h-[3px]"
            style={{ background: 'linear-gradient(90deg,#059669 0%,#0EA5E9 33%,#7C3AED 66%,#EAB308 100%)' }}
          />
          <div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-5 sm:px-8">
            <div>
              <p className="text-xs text-slate-400">GeoIncidencias / Panel</p>
              <p className="text-sm font-medium text-emerald-700 dark:text-emerald-400">GeoIncidencias Loja</p>
              <h1 className="mt-1 font-display text-2xl font-semibold tracking-tight">Panel administrativo</h1>
            </div>
            <div className="flex items-center gap-3">
              <ThemeToggle />
              <AvatarMenu username={adminUsername} onLogout={cerrarSesion} />
            </div>
          </div>
        </header>

        {/* ── Contenido ──────────────────────────────────────────────────── */}
        <div className="mx-auto w-full max-w-7xl flex-1 px-5 py-8 sm:px-8">

          {/* KPIs */}
          <section
            id="panel"
            aria-label="Resumen de incidencias"
            className="grid grid-cols-2 gap-px overflow-hidden rounded-xl border border-slate-200 bg-slate-200 shadow-sm dark:border-slate-800 dark:bg-slate-800 sm:grid-cols-4"
          >
            <KpiStat label="Total reportadas"            value={incidencias.length} accent="#334155" tint="#F1F5F9"  darkTint="#1E293B" kind="total"       loading={loading} delay={0}   />
            <KpiStat label="Recibidas"                   value={recibidas}          accent="#ef4444" tint="#FEF2F2"  darkTint="#450A0A" kind="recibido"   loading={loading} delay={60}  />
            <KpiStat label="En gestión (revisión + proceso)" value={enGestion}      accent="#f97316" tint="#FFF7ED"  darkTint="#431407" kind="proceso"    loading={loading} delay={120} />
            <KpiStat label="Resueltas (subsanado + cerrado)" value={resueltas}      accent="#22c55e" tint="#F0FDF4"  darkTint="#052E16" kind="solucionado" loading={loading} delay={180} />
          </section>

          {error && (
            <p role="alert" className="mt-6 rounded-lg border-l-4 border-red-600 bg-red-50 px-4 py-3 text-sm text-red-800 dark:bg-red-950 dark:text-red-300">
              {error}
            </p>
          )}

          {/* Mapa + Gráfico */}
          <section id="mapa" className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-3">

            {/* Mapa — 2/3 */}
            <div className="lg:col-span-2">
              <div className="mb-3 flex items-end justify-between gap-4">
                <div>
                  <h2 className="font-display text-lg font-semibold">Mapa de incidencias</h2>
                  <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">Reportes ciudadanos registrados en Loja</p>
                </div>
                <button
                  type="button"
                  onClick={() => window.location.reload()}
                  className="shrink-0 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
                >
                  ↺ Actualizar
                </button>
              </div>
              <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
                <MapaIncidencias data={incidencias} />
                <div className="flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-slate-100 px-4 py-3 text-xs text-slate-500 dark:border-slate-800 dark:text-slate-400">
                  {ESTADOS.map((e) => (
                    <span key={e.value} className="flex items-center gap-1.5">
                      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: e.color }} />
                      {e.label}
                    </span>
                  ))}
                </div>
              </div>
            </div>

            {/* Gráfico — 1/3 */}
            <div>
              <h2 className="font-display text-lg font-semibold">Reportes por categoría</h2>
              <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">Distribución del total registrado</p>
              <div className="mt-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-slate-800 dark:bg-slate-900">
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={categoriaData} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
                    <XAxis dataKey="categoria" tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={{ stroke: '#334155' }} tickLine={false} />
                    <YAxis allowDecimals={false} tick={{ fontSize: 12, fill: '#94A3B8' }} axisLine={false} tickLine={false} />
                    <Tooltip
                      cursor={{ fill: 'rgba(148,163,184,0.08)' }}
                      contentStyle={{ borderRadius: 8, border: '1px solid #334155', fontSize: 13, backgroundColor: '#0F172A', color: '#F1F5F9' }}
                    />
                    <Bar dataKey="total" radius={[6,6,0,0]} maxBarSize={48}>
                      {categoriaData.map((e) => <Cell key={e.categoria} fill={e.color} />)}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
                <div className="mt-2 flex flex-wrap gap-3 border-t border-slate-100 pt-3 text-xs text-slate-500 dark:border-slate-800 dark:text-slate-400">
                  {categoriaData.map((c) => (
                    <span key={c.categoria} className="flex items-center gap-1.5">
                      <span className="h-2 w-2 rounded-full" style={{ backgroundColor: c.color }} />
                      {c.categoria}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </section>

          {/* Parroquias */}
          <section id="parroquias" className="mt-8">
            <ReporteParroquias incidencias={incidencias} />
          </section>

          {/* Reportes */}
          <section id="reportes" className="mt-8">
            <div className="mb-4 flex items-center justify-between gap-3">
              <h2 className="font-display text-lg font-semibold">Reportes</h2>
              <div className="flex items-center gap-2">
                <span className="text-sm text-slate-500 dark:text-slate-400">{incidencias.length} registros</span>
                <button type="button" onClick={exportarCSV} className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700">
                  CSV
                </button>
                <button type="button" onClick={exportarPDF} className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700">
                  PDF (lista actual)
                </button>
              </div>
            </div>

            {/* Informe mensual consolidado (PDF del servidor) */}
            <div className="mb-4 flex flex-wrap items-end gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 shadow-sm dark:border-slate-800 dark:bg-slate-900">
              <div className="mr-auto">
                <p className="text-sm font-medium">Informe mensual consolidado</p>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  PDF con las incidencias del mes agrupadas por estado
                </p>
              </div>
              <label className="text-xs text-slate-500 dark:text-slate-400">
                Mes
                <select
                  value={mesInforme}
                  onChange={(e) => setMesInforme(Number(e.target.value))}
                  className="mt-1 block rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm text-slate-800 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
                >
                  {MESES.map((m, i) => (
                    <option key={m} value={i + 1}>{m}</option>
                  ))}
                </select>
              </label>
              <label className="text-xs text-slate-500 dark:text-slate-400">
                Año
                <input
                  type="number"
                  min={2024}
                  max={2100}
                  value={anioInforme}
                  onChange={(e) => setAnioInforme(Number(e.target.value))}
                  className="mt-1 block w-24 rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm text-slate-800 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
                />
              </label>
              <button
                type="button"
                onClick={descargarInformeMensual}
                disabled={generandoInforme}
                className="rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-slate-300"
              >
                {generandoInforme ? 'Generando...' : 'Descargar PDF'}
              </button>
              {errorInforme && (
                <p role="alert" className="w-full text-sm text-red-600 dark:text-red-400">{errorInforme}</p>
              )}
            </div>

            {/* Filtro de prioridad: reportes de suscriptores VIP */}
            <div className="mb-3">
              <button
                type="button"
                onClick={() => setSoloPrioritarios((v) => !v)}
                aria-pressed={soloPrioritarios}
                className={`flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors ${
                  soloPrioritarios
                    ? 'border-amber-500 bg-amber-500 text-white'
                    : 'border-amber-300 bg-amber-50 text-amber-800 hover:border-amber-400 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-300'
                }`}
              >
                ★ Solo prioritarios (VIP)
                <span className={`rounded-full px-1.5 text-xs ${soloPrioritarios ? 'bg-white/25' : 'bg-amber-100 dark:bg-amber-900'}`}>
                  {prioritarias}
                </span>
              </button>
            </div>

            {/* Tabs filtro */}
            <div className="mb-4 flex flex-wrap gap-2">
              {tabs.map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => setFiltroEstado(tab.key)}
                  className={`flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors ${
                    filtroEstado === tab.key
                      ? 'border-slate-900 bg-slate-900 text-white dark:border-slate-100 dark:bg-slate-100 dark:text-slate-900'
                      : 'border-slate-300 bg-white text-slate-600 hover:border-slate-400 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-300 dark:hover:border-slate-500'
                  }`}
                >
                  <span className="h-2 w-2 rounded-full" style={{ backgroundColor: tab.dot }} />
                  {tab.label}
                  <span className={`rounded-full px-1.5 text-xs ${filtroEstado === tab.key ? 'bg-white/20' : 'bg-slate-100 dark:bg-slate-800'}`}>
                    {tab.count}
                  </span>
                </button>
              ))}
            </div>

            {/* Lista */}
            <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
              {loading ? (
                <p className="px-4 py-8 text-center text-sm text-slate-500 dark:text-slate-400">Cargando reportes...</p>
              ) : reportesFiltrados.length === 0 ? (
                <p className="px-4 py-8 text-center text-sm text-slate-500 dark:text-slate-400">No hay reportes en este estado.</p>
              ) : (
                <div className="divide-y divide-slate-100 dark:divide-slate-800">
                  {reportesFiltrados.slice(0, 15).map((inc) => {
                    const meta = CATEGORIA_META[inc.categoria];
                    return (
                      <div
                        key={inc.id}
                        onClick={() => setReporteSeleccionado(inc)}
                        className="flex cursor-pointer items-center gap-3 px-4 py-3 transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/50"
                      >
                        {inc.foto ? (
                          <img src={inc.foto} alt={inc.categoria} className="h-11 w-11 shrink-0 rounded-lg object-cover" />
                        ) : (
                          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg text-xs font-semibold text-white" style={{ backgroundColor: meta?.color || '#94A3B8' }}>
                            {(meta?.label || inc.categoria).slice(0, 2).toUpperCase()}
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <p className="truncate font-medium">{meta?.label || inc.categoria}</p>
                          <p className="truncate text-sm text-slate-500 dark:text-slate-400">{inc.descripcion || 'Sin descripción'}</p>
                        </div>
                        <div className="hidden shrink-0 text-right text-xs text-slate-500 dark:text-slate-400 sm:block">
                          <p>{inc.usuario_nombre || 'Anónimo'}</p>
                          <p>{inc.fecha_creacion ? new Date(inc.fecha_creacion).toLocaleDateString('es-EC') : '—'}</p>
                        </div>
                        {(inc.prioritaria || inc.anonimo) && (
                          <div className="flex shrink-0 flex-col items-end gap-1 sm:flex-row sm:items-center">
                            {inc.prioritaria && (
                              <span className="whitespace-nowrap rounded-full border border-amber-300 bg-amber-50 px-2 py-0.5 text-[11px] font-semibold text-amber-800 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-300">
                                ★ Prioritario
                              </span>
                            )}
                            {inc.anonimo && (
                              <span className="whitespace-nowrap rounded-full border border-slate-300 bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-600 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300">
                                Anónimo
                              </span>
                            )}
                          </div>
                        )}
                        <span className={`shrink-0 whitespace-nowrap rounded-full border px-2.5 py-0.5 text-xs font-medium ${claseBadge(inc.estado)}`}>
                          {etiquetaEstado(inc.estado)}
                        </span>
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="shrink-0 text-slate-300 dark:text-slate-600">
                          <path d="m9 18 6-6-6-6" />
                        </svg>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </section>
        </div>
      </main>

      {reporteSeleccionado && (
        <ReporteModal
          incidencia={reporteSeleccionado}
          onClose={() => setReporteSeleccionado(null)}
          onEstadoActualizado={actualizarEstadoLocal}
        />
      )}
    </div>
  );
}