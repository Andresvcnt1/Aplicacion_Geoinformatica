'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import api from '@/lib/api';

const MiniMapa = dynamic(() => import('./MiniMapa'), {
  ssr: false,
  loading: () => <div className="h-[180px] w-full animate-pulse rounded-lg bg-slate-100 dark:bg-slate-800" />,
});

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

const ESTADOS = ['Recibido', 'En proceso', 'Solucionado'] as const;

const ESTADO_STYLE: Record<string, { active: string; idle: string }> = {
  Recibido: {
    active: 'bg-red-500 text-white border-red-500',
    idle: 'bg-white text-slate-600 border-slate-300 hover:border-red-300 dark:bg-slate-900 dark:text-slate-300 dark:border-slate-600',
  },
  'En proceso': {
    active: 'bg-orange-500 text-white border-orange-500',
    idle: 'bg-white text-slate-600 border-slate-300 hover:border-orange-300 dark:bg-slate-900 dark:text-slate-300 dark:border-slate-600',
  },
  Solucionado: {
    active: 'bg-emerald-500 text-white border-emerald-500',
    idle: 'bg-white text-slate-600 border-slate-300 hover:border-emerald-300 dark:bg-slate-900 dark:text-slate-300 dark:border-slate-600',
  },
};

function getCoordinates(inc: Incidencia): [number, number] | null {
  if (inc.ubicacion && typeof inc.ubicacion === 'object' && 'coordinates' in inc.ubicacion) {
    const [lng, lat] = (inc.ubicacion as { coordinates: [number, number] }).coordinates;
    return [lat, lng];
  }
  if (inc.geometry?.coordinates) {
    const [lng, lat] = inc.geometry.coordinates;
    return [lat, lng];
  }
  if (typeof inc.ubicacion === 'string' && inc.ubicacion.includes('POINT')) {
    const match = inc.ubicacion.match(/POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)/);
    if (match) {
      return [parseFloat(match[2]), parseFloat(match[1])];
    }
  }
  return null;
}

export default function ReporteModal({
  incidencia,
  onClose,
  onEstadoActualizado,
}: {
  incidencia: Incidencia;
  onClose: () => void;
  onEstadoActualizado: (id: number, nuevoEstado: string) => void;
}) {
  const [estadoActual, setEstadoActual] = useState(incidencia.estado);
  const [guardando, setGuardando] = useState(false);
  const [guardado, setGuardado] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [onClose]);

  const coords = getCoordinates(incidencia);

  const cambiarEstado = async (nuevoEstado: string) => {
    if (nuevoEstado === estadoActual || guardando) return;
    setGuardando(true);
    setGuardado(false);
    setError('');
    try {
      await api.post(`/incidencias/${incidencia.id}/estado/`, { estado: nuevoEstado });
      setEstadoActual(nuevoEstado);
      onEstadoActualizado(incidencia.id, nuevoEstado);
      setGuardado(true);
      setTimeout(() => setGuardado(false), 2000);
    } catch {
      setError('No se pudo actualizar el estado. Intenta de nuevo.');
    } finally {
      setGuardando(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[1000] flex items-center justify-center bg-slate-900/60 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl bg-white shadow-xl dark:bg-slate-900"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4 dark:border-slate-800">
          <h3 className="font-display text-lg font-semibold text-slate-900 dark:text-slate-50">
            Reporte #{incidencia.id}
          </h3>
          <button
            type="button"
            onClick={onClose}
            aria-label="Cerrar"
            className="flex h-8 w-8 items-center justify-center rounded-full text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:hover:bg-slate-800"
          >
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="px-5 py-4">
          {incidencia.foto ? (
            <img
              src={incidencia.foto}
              alt={`Evidencia: ${incidencia.categoria}`}
              className="h-56 w-full rounded-lg object-cover"
            />
          ) : (
            <div className="flex h-56 w-full items-center justify-center rounded-lg bg-slate-100 text-sm text-slate-400 dark:bg-slate-800">
              Sin foto de evidencia
            </div>
          )}

          <div className="mt-4 space-y-1">
            <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{incidencia.categoria}</p>
            <p className="text-slate-800 dark:text-slate-200">{incidencia.descripcion || 'Sin descripción'}</p>
          </div>

          <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-sm text-slate-500 dark:text-slate-400">
            <span>Reportado por: {incidencia.usuario_nombre || 'Anónimo'}</span>
            {incidencia.fecha_creacion && (
              <span>{new Date(incidencia.fecha_creacion).toLocaleString('es-EC')}</span>
            )}
          </div>

          {coords && (
            <div className="mt-4 overflow-hidden rounded-lg border border-slate-200 dark:border-slate-800">
              <MiniMapa lat={coords[0]} lng={coords[1]} color={ESTADO_STYLE[estadoActual]?.active.includes('red') ? '#ef4444' : undefined} />
            </div>
          )}

          <div className="mt-5">
            <p className="mb-2 text-sm font-medium text-slate-700 dark:text-slate-300">Estado</p>
            <div className="flex flex-wrap gap-2">
              {ESTADOS.map((estado) => (
                <button
                  key={estado}
                  type="button"
                  disabled={guardando}
                  onClick={() => cambiarEstado(estado)}
                  className={`rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-60 ${
                    estado === estadoActual ? ESTADO_STYLE[estado].active : ESTADO_STYLE[estado].idle
                  }`}
                >
                  {estado}
                </button>
              ))}
            </div>
            <div className="mt-2 h-5 text-sm">
              {guardando && <span className="text-slate-400">Guardando...</span>}
              {guardado && !guardando && <span className="text-emerald-600 dark:text-emerald-400">Guardado ✓</span>}
              {error && <span className="text-red-600 dark:text-red-400">{error}</span>}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}