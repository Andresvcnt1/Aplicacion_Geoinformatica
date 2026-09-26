'use client';

import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import axios from 'axios';
import api from '@/lib/api';

interface Incidencia {
  id: number;
  categoria: string;
  descripcion: string;
  estado: string;
  fecha_creacion?: string;
  usuario_nombre?: string;
  ubicacion?: string;
  geometry?: { type: string; coordinates: [number, number] };
}

const MapaIncidencias = dynamic(() => import('../components/MapaIncidencias'), {
  ssr: false,
  loading: () => <div className="h-[500px] animate-pulse bg-slate-100" />,
});

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

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4 sm:px-8">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.16em] text-teal-700">GeoIncidencias Loja</p>
            <h1 className="mt-1 text-xl font-semibold">Panel administrativo</h1>
          </div>
          <button
            type="button"
            onClick={cerrarSesion}
            className="rounded-md border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-100"
          >
            Cerrar sesión
          </button>
        </div>
      </header>

      <div className="mx-auto max-w-7xl px-5 py-8 sm:px-8">
        <section aria-label="Resumen de incidencias" className="grid grid-cols-2 gap-px overflow-hidden border border-slate-200 bg-slate-200 sm:grid-cols-4">
          {[
            { label: 'Total reportadas', value: incidencias.length, tone: 'text-slate-900' },
            { label: 'Recibidas', value: recibidas, tone: 'text-red-700' },
            { label: 'En proceso', value: enProceso, tone: 'text-amber-700' },
            { label: 'Solucionadas', value: solucionadas, tone: 'text-emerald-700' },
          ].map((stat) => (
            <div key={stat.label} className="bg-white px-5 py-4">
              <p className="text-sm text-slate-500">{stat.label}</p>
              <p className={`mt-2 text-2xl font-semibold ${stat.tone}`}>{loading ? '—' : stat.value}</p>
            </div>
          ))}
        </section>

        <section className="mt-8">
          <div className="mb-4 flex items-end justify-between gap-4">
            <div>
              <h2 className="text-lg font-semibold">Mapa de incidencias</h2>
              <p className="mt-1 text-sm text-slate-500">Reportes ciudadanos registrados en Loja</p>
            </div>
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="shrink-0 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100"
            >
              Actualizar
            </button>
          </div>

          {error && <p role="alert" className="mb-4 border-l-4 border-red-600 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</p>}
          <div className="overflow-hidden border border-slate-200 bg-white">
            <MapaIncidencias data={incidencias} />
          </div>
        </section>

        <section className="mt-8">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold">Reportes recientes</h2>
            <span className="text-sm text-slate-500">{incidencias.length} registros</span>
          </div>
          <div className="overflow-x-auto border border-slate-200 bg-white">
            <table className="w-full min-w-[640px] border-collapse text-left text-sm">
              <thead className="border-b border-slate-200 bg-slate-100 text-xs uppercase text-slate-500">
                <tr>
                  <th className="px-4 py-3 font-semibold">Categoría</th>
                  <th className="px-4 py-3 font-semibold">Descripción</th>
                  <th className="px-4 py-3 font-semibold">Reportado por</th>
                  <th className="px-4 py-3 font-semibold">Estado</th>
                  <th className="px-4 py-3 font-semibold">Fecha</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {loading ? (
                  <tr><td colSpan={5} className="px-4 py-8 text-center text-slate-500">Cargando reportes...</td></tr>
                ) : incidencias.length === 0 ? (
                  <tr><td colSpan={5} className="px-4 py-8 text-center text-slate-500">Aún no hay incidencias registradas.</td></tr>
                ) : incidencias.slice(0, 10).map((incidencia) => (
                  <tr key={incidencia.id}>
                    <td className="px-4 py-3 font-medium">{incidencia.categoria}</td>
                    <td className="max-w-xs truncate px-4 py-3 text-slate-600">{incidencia.descripcion || 'Sin descripción'}</td>
                    <td className="px-4 py-3 text-slate-600">{incidencia.usuario_nombre || 'Anónimo'}</td>
                    <td className="px-4 py-3">{incidencia.estado}</td>
                    <td className="px-4 py-3 text-slate-600">
                      {incidencia.fecha_creacion ? new Date(incidencia.fecha_creacion).toLocaleDateString('es-EC') : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
  );
}