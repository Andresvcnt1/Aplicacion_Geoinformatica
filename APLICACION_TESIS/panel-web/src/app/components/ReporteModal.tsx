'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import axios from 'axios';
import api from '@/lib/api';
import {
  EXIGEN_OBSERVACION,
  claseBadge,
  colorEstado,
  etiquetaEstado,
  siguientesEstados,
  type EstadoValor,
} from '@/lib/estados';

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
  foto_url?: string;
  foto?: string; // el endpoint /reportes/ manda la foto bajo este nombre
  geometry?: { type: string; coordinates: [number, number] };
  ubicacion?: { type: string; coordinates: [number, number] } | string;
}

interface HistorialItem {
  id: number;
  estado_anterior: string | null;
  estado_nuevo: string;
  estado_nuevo_display?: string;
  fecha_cambio: string;
  observacion: string;
  responsable: string | null;
}

const IDLE_BTN =
  'bg-white text-slate-600 border-slate-300 hover:border-slate-400 dark:bg-slate-900 dark:text-slate-300 dark:border-slate-600';

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
  const [seleccionado, setSeleccionado] = useState<EstadoValor | null>(null);
  const [observacion, setObservacion] = useState('');
  const [guardando, setGuardando] = useState(false);
  const [guardado, setGuardado] = useState(false);
  const [error, setError] = useState('');

  const [historial, setHistorial] = useState<HistorialItem[]>([]);
  const [cargandoHistorial, setCargandoHistorial] = useState(true);
  const [errorHistorial, setErrorHistorial] = useState('');

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [onClose]);

  useEffect(() => {
    let activo = true;
    setCargandoHistorial(true);
    setErrorHistorial('');
    api
      .get(`/incidencias/${incidencia.id}/historial/`)
      .then((res) => {
        if (activo) setHistorial(Array.isArray(res.data) ? res.data : []);
      })
      .catch(() => {
        if (activo) setErrorHistorial('No se pudo cargar el historial.');
      })
      .finally(() => {
        if (activo) setCargandoHistorial(false);
      });
    return () => {
      activo = false;
    };
  }, [incidencia.id]);

  const coords = getCoordinates(incidencia);
  const fotoEvidencia = incidencia.foto_url ?? incidencia.foto;
  const opciones = siguientesEstados(estadoActual);
  const requiereObservacion = seleccionado !== null && EXIGEN_OBSERVACION.includes(seleccionado);

  const guardarCambio = async () => {
    if (!seleccionado || guardando) return;
    if (requiereObservacion && !observacion.trim()) {
      setError('Este estado requiere una observación.');
      return;
    }
    setGuardando(true);
    setGuardado(false);
    setError('');
    try {
      const res = await api.post(`/incidencias/${incidencia.id}/estado/`, {
        estado: seleccionado,
        observacion: observacion.trim(),
      });
      const nuevoEstado: string = res.data.estado;
      setEstadoActual(nuevoEstado);
      onEstadoActualizado(incidencia.id, nuevoEstado);
      if (res.data.historial) setHistorial((prev) => [...prev, res.data.historial as HistorialItem]);
      setSeleccionado(null);
      setObservacion('');
      setGuardado(true);
      setTimeout(() => setGuardado(false), 2500);
    } catch (err) {
      const mensaje = axios.isAxiosError(err) ? err.response?.data?.error : undefined;
      setError(mensaje || 'No se pudo actualizar el estado. Intenta de nuevo.');
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
          {fotoEvidencia ? (
            <img
              src={fotoEvidencia}
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
              <MiniMapa lat={coords[0]} lng={coords[1]} color={colorEstado(estadoActual)} />
            </div>
          )}

          {/* ── Estado actual + cambio ─────────────────────────────────── */}
          <div className="mt-5">
            <div className="mb-2 flex items-center gap-2">
              <p className="text-sm font-medium text-slate-700 dark:text-slate-300">Estado actual</p>
              <span className={`rounded-full border px-2.5 py-0.5 text-xs font-medium ${claseBadge(estadoActual)}`}>
                {etiquetaEstado(estadoActual)}
              </span>
            </div>

            {opciones.length === 0 ? (
              <p className="text-sm text-slate-500 dark:text-slate-400">
                Estado final: no hay más cambios disponibles.
              </p>
            ) : (
              <>
                <p className="mb-2 text-sm text-slate-500 dark:text-slate-400">Cambiar a:</p>
                <div className="flex flex-wrap gap-2">
                  {opciones.map((op) => (
                    <button
                      key={op.value}
                      type="button"
                      disabled={guardando}
                      onClick={() => {
                        setSeleccionado(op.value);
                        setError('');
                      }}
                      className={`rounded-full border px-3.5 py-1.5 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-60 ${
                        seleccionado === op.value ? op.activo : IDLE_BTN
                      }`}
                    >
                      {op.label}
                    </button>
                  ))}
                </div>

                {seleccionado && (
                  <div className="mt-3">
                    <label className="mb-1 block text-sm font-medium text-slate-700 dark:text-slate-300">
                      Observación {requiereObservacion ? <span className="text-red-600">(obligatoria)</span> : <span className="text-slate-400">(opcional)</span>}
                    </label>
                    <textarea
                      value={observacion}
                      onChange={(e) => setObservacion(e.target.value)}
                      rows={3}
                      maxLength={500}
                      placeholder="Ej.: cuadrilla asignada, se programó la reparación…"
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 outline-none focus:border-slate-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
                    />
                    <button
                      type="button"
                      onClick={guardarCambio}
                      disabled={guardando}
                      className="mt-2 rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-slate-300"
                    >
                      {guardando ? 'Guardando...' : `Guardar cambio a «${etiquetaEstado(seleccionado)}»`}
                    </button>
                  </div>
                )}
              </>
            )}

            <div className="mt-2 min-h-5 text-sm">
              {guardado && !guardando && <span className="text-emerald-600 dark:text-emerald-400">Estado actualizado ✓</span>}
              {error && <span role="alert" className="text-red-600 dark:text-red-400">{error}</span>}
            </div>
          </div>

          {/* ── Historial (trazabilidad) ───────────────────────────────── */}
          <div className="mt-4 border-t border-slate-100 pt-4 dark:border-slate-800">
            <p className="mb-3 text-sm font-medium text-slate-700 dark:text-slate-300">Historial de estados</p>
            {cargandoHistorial ? (
              <p className="text-sm text-slate-400">Cargando historial...</p>
            ) : errorHistorial ? (
              <p className="text-sm text-red-600 dark:text-red-400">{errorHistorial}</p>
            ) : historial.length === 0 ? (
              <p className="text-sm text-slate-400">Sin registros.</p>
            ) : (
              <ol className="space-y-4">
                {historial.map((h, i) => (
                  <li key={h.id} className="flex gap-3">
                    <div className="flex flex-col items-center">
                      <span className="mt-1 h-3 w-3 shrink-0 rounded-full" style={{ backgroundColor: colorEstado(h.estado_nuevo) }} />
                      {i < historial.length - 1 && <span className="mt-1 w-px flex-1 bg-slate-200 dark:bg-slate-700" />}
                    </div>
                    <div className="min-w-0 flex-1 pb-1">
                      <p className="text-sm font-semibold text-slate-800 dark:text-slate-100">
                        {h.estado_nuevo_display || etiquetaEstado(h.estado_nuevo)}
                      </p>
                      <p className="text-xs text-slate-500 dark:text-slate-400">
                        {new Date(h.fecha_cambio).toLocaleString('es-EC')}
                        {h.responsable ? ` · ${h.responsable}` : ''}
                      </p>
                      {h.observacion && (
                        <p className="mt-1 text-sm text-slate-600 dark:text-slate-300">{h.observacion}</p>
                      )}
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}