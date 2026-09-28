'use client';

import { useEffect, useMemo, useState } from 'react';
import api from '@/lib/api';
import booleanPointInPolygon from '@turf/boolean-point-in-polygon';
import { point as turfPoint } from '@turf/helpers';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts';

interface Incidencia {
  id: number;
  categoria: string;
  descripcion: string;
  estado: string;
  geometry?: { type: string; coordinates: [number, number] };
  ubicacion?: { type: string; coordinates: [number, number] } | string;
}

interface GeocercaFeature {
  type: 'Feature';
  geometry: { type: string; coordinates: unknown };
  properties: { id: number; nombre: string; activa: boolean };
}

const PARROQUIAS_URBANAS = ['Sagrario', 'Sucre', 'El Valle', 'San Sebastián', 'Punzará', 'Carigán'];

function normalizar(texto: string) {
  return texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLowerCase();
}

function getCoordsLngLat(inc: Incidencia): [number, number] | null {
  if (inc.ubicacion && typeof inc.ubicacion === 'object' && 'coordinates' in inc.ubicacion) {
    return (inc.ubicacion as { coordinates: [number, number] }).coordinates;
  }
  if (inc.geometry?.coordinates) return inc.geometry.coordinates;
  if (typeof inc.ubicacion === 'string' && inc.ubicacion.includes('POINT')) {
    const match = inc.ubicacion.match(/POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)/);
    if (match) return [parseFloat(match[1]), parseFloat(match[2])];
  }
  return null;
}

const COLORES = ['#ef4444', '#f97316', '#eab308', '#22c55e', '#0ea5e9', '#7c3aed'];

export default function ReporteParroquias({ incidencias }: { incidencias: Incidencia[] }) {
  const [geocercas, setGeocercas] = useState<Array<GeocercaFeature & { nombreCorto: string }>>([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState('');

  useEffect(() => {
    const cargar = async () => {
      try {
        const response  = await api.get('/geocercas-geojson/');
        const features: GeocercaFeature[] = response.data.features || [];
        const filtradas = features
          .map((f) => {
            const nombreNorm = normalizar(f.properties.nombre || '');
            const match = PARROQUIAS_URBANAS.find((p) => nombreNorm.includes(normalizar(p)));
            return match ? { ...f, nombreCorto: match } : null;
          })
          .filter((f): f is GeocercaFeature & { nombreCorto: string } => f !== null);
        setGeocercas(filtradas);
      } catch {
        setError('No se pudieron cargar los límites de las parroquias.');
      } finally {
        setLoading(false);
      }
    };
    void cargar();
  }, []);

  const conteo = useMemo(() => {
    if (geocercas.length === 0) return [];
    const puntos = incidencias
      .map((inc) => { const c = getCoordsLngLat(inc); return c ? turfPoint(c) : null; })
      .filter((p): p is ReturnType<typeof turfPoint> => p !== null);
    return geocercas
      .map((geo) => ({
        parroquia: geo.nombreCorto,
        total: puntos.filter((p) => booleanPointInPolygon(p, geo as never)).length,
      }))
      .sort((a, b) => b.total - a.total);
  }, [geocercas, incidencias]);

  const totalGeneral = conteo.reduce((sum, c) => sum + c.total, 0);
  const top = conteo[0];

  const exportarPDF = async () => {
    const { default: jsPDF }     = await import('jspdf');
    const { default: autoTable } = await import('jspdf-autotable');
    const doc = new jsPDF();
    const pageWidth = doc.internal.pageSize.getWidth();
    doc.setFillColor(15, 23, 42); doc.rect(0, 0, pageWidth, 22, 'F');
    doc.setTextColor(255, 255, 255); doc.setFontSize(15); doc.setFont('helvetica', 'bold');
    doc.text('GeoIncidencias Loja', 14, 13);
    doc.setFontSize(9); doc.setFont('helvetica', 'normal');
    doc.text('Incidencias por parroquia', 14, 19);
    doc.text(new Date().toLocaleString('es-EC'), pageWidth - 14, 13, { align: 'right' });
    autoTable(doc, {
      startY: 30,
      head: [['#', 'Parroquia', 'Total', '% del total']],
      body: conteo.map((c, i) => [
        i + 1, c.parroquia, c.total,
        totalGeneral > 0 ? `${Math.round((c.total / totalGeneral) * 100)}%` : '0%',
      ]),
      styles: { fontSize: 10, cellPadding: 5 },
      headStyles: { fillColor: [15, 23, 42], textColor: 255, fontStyle: 'bold' },
      alternateRowStyles: { fillColor: [248, 250, 252] },
      didParseCell: (data) => {
        if (data.section === 'body' && data.row.index === 0) {
          data.cell.styles.fillColor = [254, 226, 226];
          data.cell.styles.fontStyle = 'bold';
        }
      },
    });
    doc.setFontSize(8); doc.setTextColor(150);
    doc.text('Nota: límites con traslapes menores pueden generar doble conteo en zonas de borde.', 14, doc.internal.pageSize.getHeight() - 10);
    doc.save(`incidencias_por_parroquia_${new Date().toISOString().slice(0, 10)}.pdf`);
  };

  if (loading) return <div className="h-[300px] animate-pulse rounded-xl bg-slate-100 dark:bg-slate-800" />;

  if (error || geocercas.length === 0) {
    return (
      <div className="rounded-xl border border-slate-200 bg-white p-6 text-sm text-slate-500 dark:border-slate-800 dark:bg-slate-900 dark:text-slate-400">
        {error || 'Aún no hay geocercas de parroquias registradas.'}
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900">
      {/* Header */}
      <div className="mb-4 flex items-start justify-between gap-3">
        <div>
          <h3 className="font-display text-lg font-semibold text-slate-900 dark:text-slate-100">
            Incidencias por parroquia
          </h3>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
            Para identificar zonas prioritarias de atención municipal
          </p>
        </div>
        <button
          type="button"
          onClick={exportarPDF}
          className="shrink-0 rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition-colors hover:bg-slate-100 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-200 dark:hover:bg-slate-700"
        >
          PDF
        </button>
      </div>

      {/* Banner zona prioritaria */}
      {top && (
        <div className="mb-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 dark:border-red-900 dark:bg-red-950/60">
          <p className="text-sm text-red-800 dark:text-red-300">
            <span className="font-semibold">Zona prioritaria: {top.parroquia}</span>
            {' '}— {top.total} de {totalGeneral} incidencias registradas
          </p>
        </div>
      )}

      {/* Gráfico horizontal */}
      <ResponsiveContainer width="100%" height={Math.max(220, conteo.length * 44)}>
        <BarChart data={conteo} layout="vertical" margin={{ top: 0, right: 24, left: 8, bottom: 0 }}>
          <XAxis
            type="number" allowDecimals={false}
            tick={{ fontSize: 12, fill: '#94A3B8' }}
            axisLine={{ stroke: '#334155' }} tickLine={false}
          />
          <YAxis
            type="category" dataKey="parroquia" width={105}
            tick={{ fontSize: 12, fill: '#94A3B8' }}
            axisLine={false} tickLine={false}
          />
          <Tooltip
            contentStyle={{
              borderRadius: 8, border: '1px solid #334155', fontSize: 13,
              backgroundColor: '#0F172A', color: '#F1F5F9',
            }}
          />
          <Bar dataKey="total" radius={[0,6,6,0]} maxBarSize={28}>
            {conteo.map((entry, i) => (
              <Cell key={entry.parroquia} fill={COLORES[i % COLORES.length]} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>

      <p className="mt-3 text-xs text-slate-400 dark:text-slate-500">
        Nota: si dos parroquias tienen límites que se traslapan, una incidencia en esa zona puede contarse en ambas.
      </p>
    </div>
  );
}