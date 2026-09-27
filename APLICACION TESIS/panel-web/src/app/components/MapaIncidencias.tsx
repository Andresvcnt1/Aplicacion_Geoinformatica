'use client';

import { MapContainer, TileLayer, Marker, Popup, Tooltip, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { useMemo, useState } from 'react';

delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

interface Incidencia {
  id: number;
  categoria: string;
  descripcion: string;
  estado: string;
  foto?: string;
  geometry?: { type: string; coordinates: [number, number] };
  ubicacion?: { type: string; coordinates: [number, number] } | string;
}

const getColor = (estado: string) => {
  if (estado === 'Recibido') return '#ef4444';
  if (estado === 'En proceso') return '#f97316';
  if (estado === 'Solucionado') return '#22c55e';
  return '#6b7280';
};

const ESTADO_BADGE: Record<string, string> = {
  Recibido: 'bg-red-50 text-red-700 border-red-200 dark:bg-red-950 dark:text-red-300 dark:border-red-900',
  'En proceso': 'bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950 dark:text-orange-300 dark:border-orange-900',
  Solucionado: 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300 dark:border-emerald-900',
};

const getCoordinates = (inc: Incidencia): [number, number] | null => {
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
      const lng = parseFloat(match[1]);
      const lat = parseFloat(match[2]);
      return [lat, lng];
    }
  }
  return null;
};

interface ClusterPoint {
  incidencia: Incidencia;
  coords: [number, number];
}

interface Cluster {
  id: string;
  coords: [number, number];
  items: ClusterPoint[];
}

const CLUSTER_PIXEL_RADIUS = 48;

function buildClusterIcon(photoUrl: string | undefined, extraCount: number, estadoColor: string) {
  const size = 54;
  const imgHtml = photoUrl
    ? `<img src="${photoUrl}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;display:block;" />`
    : `<div style="width:100%;height:100%;border-radius:50%;background:${estadoColor};"></div>`;

  const badge =
    extraCount > 0
      ? `<div style="position:absolute;bottom:-2px;right:-2px;min-width:22px;height:22px;padding:0 5px;border-radius:11px;background:#ee2a7b;border:2px solid white;color:white;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;">+${extraCount}</div>`
      : '';

  return L.divIcon({
    className: 'custom-cluster-icon',
    html: `
      <div style="position:relative;width:${size}px;height:${size}px;">
        <div style="width:100%;height:100%;border-radius:50%;padding:3px;background:linear-gradient(45deg,#f9ce34,#ee2a7b,#6228d7);box-shadow:0 3px 8px rgba(0,0,0,0.35);">
          <div style="width:100%;height:100%;border-radius:50%;padding:2px;background:white;">
            ${imgHtml}
          </div>
        </div>
        ${badge}
      </div>
    `,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
}

function ClusterMarkers({ points }: { points: ClusterPoint[] }) {
  const map = useMap();
  const [version, setVersion] = useState(0);

  useMapEvents({
    zoomend: () => setVersion((v) => v + 1),
    moveend: () => setVersion((v) => v + 1),
  });

  const clusters = useMemo<Cluster[]>(() => {
    if (!map) return [];
    const used = new Array(points.length).fill(false);
    const result: Cluster[] = [];

    for (let i = 0; i < points.length; i++) {
      if (used[i]) continue;
      const base = points[i];
      const basePixel = map.latLngToLayerPoint(L.latLng(base.coords[0], base.coords[1]));
      const group: ClusterPoint[] = [base];
      used[i] = true;

      for (let j = i + 1; j < points.length; j++) {
        if (used[j]) continue;
        const otherPixel = map.latLngToLayerPoint(L.latLng(points[j].coords[0], points[j].coords[1]));
        if (basePixel.distanceTo(otherPixel) <= CLUSTER_PIXEL_RADIUS) {
          group.push(points[j]);
          used[j] = true;
        }
      }

      const avgLat = group.reduce((sum, p) => sum + p.coords[0], 0) / group.length;
      const avgLng = group.reduce((sum, p) => sum + p.coords[1], 0) / group.length;

      result.push({
        id: group.map((g) => g.incidencia.id).join('-'),
        coords: [avgLat, avgLng],
        items: group,
      });
    }

    return result;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [points, map, version]);

  return (
    <>
      {clusters.map((cluster) => {
        const main = cluster.items[0].incidencia;
        const extraCount = cluster.items.length - 1;
        const icon = buildClusterIcon(main.foto, extraCount, getColor(main.estado));

        if (cluster.items.length === 1) {
          return (
            <Marker key={cluster.id} position={cluster.coords} icon={icon}>
              <Popup>
                <div className="min-w-[190px]">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-semibold text-slate-900 dark:text-slate-100">{main.categoria}</span>
                    <span
                      className={`whitespace-nowrap rounded-full border px-2 py-0.5 text-[10px] font-medium ${
                        ESTADO_BADGE[main.estado] || 'bg-slate-50 text-slate-700 border-slate-200'
                      }`}
                    >
                      {main.estado}
                    </span>
                  </div>
                  <p className="mt-1 text-xs text-slate-600 dark:text-slate-300">
                    {main.descripcion || 'Sin descripción'}
                  </p>
                  {main.foto && (
                    <img
                      src={main.foto}
                      alt={`Evidencia: ${main.categoria}`}
                      className="mt-2 w-full rounded-lg object-cover"
                      style={{ maxHeight: 160 }}
                    />
                  )}
                </div>
              </Popup>
            </Marker>
          );
        }

        return (
          <Marker
            key={cluster.id}
            position={cluster.coords}
            icon={icon}
            eventHandlers={{
              click: () => {
                const bounds = L.latLngBounds(cluster.items.map((item) => item.coords));
                map.fitBounds(bounds, { padding: [60, 60], maxZoom: 19 });
              },
            }}
          >
            <Tooltip permanent direction="bottom" offset={[0, 30]} className="cluster-label">
              y {extraCount} más
            </Tooltip>
            <Popup maxWidth={230}>
              <div className="min-w-[190px]">
                <p className="font-semibold text-slate-900 dark:text-slate-100">
                  {cluster.items.length} incidencias en esta zona
                </p>
                <div className="mt-2 flex max-h-[260px] flex-col gap-2 overflow-y-auto">
                  {cluster.items.map(({ incidencia }) => (
                    <div key={incidencia.id} className="flex items-center gap-2">
                      {incidencia.foto ? (
                        <img
                          src={incidencia.foto}
                          alt={incidencia.categoria}
                          className="h-10 w-10 shrink-0 rounded-lg object-cover"
                        />
                      ) : (
                        <div
                          className="h-10 w-10 shrink-0 rounded-lg"
                          style={{ background: getColor(incidencia.estado) }}
                        />
                      )}
                      <div className="text-xs">
                        <p className="font-medium text-slate-900 dark:text-slate-100">{incidencia.categoria}</p>
                        <span
                          className={`inline-flex rounded-full border px-1.5 py-0.5 text-[10px] font-medium ${
                            ESTADO_BADGE[incidencia.estado] || 'bg-slate-50 text-slate-700 border-slate-200'
                          }`}
                        >
                          {incidencia.estado}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </Popup>
          </Marker>
        );
      })}
    </>
  );
}

export default function MapaIncidencias({ data }: { data: Incidencia[] }) {
  const points: ClusterPoint[] = data
    .map((incidencia) => {
      const coords = getCoordinates(incidencia);
      return coords ? { incidencia, coords } : null;
    })
    .filter((p): p is ClusterPoint => p !== null);

  return (
    <MapContainer center={[-4.0085, -79.2239]} zoom={13} className="h-[500px] w-full rounded-lg z-0">
      <TileLayer url={process.env.NEXT_PUBLIC_TILE_URL || 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'} className="map-tiles-dark" />
      <ClusterMarkers points={points} />
    </MapContainer>
  );
}
