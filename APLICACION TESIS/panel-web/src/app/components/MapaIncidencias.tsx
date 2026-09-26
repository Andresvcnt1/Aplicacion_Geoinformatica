'use client';

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

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
  geometry?: { type: string; coordinates: [number, number] };
  ubicacion?: string; // Por si Django lo manda como texto
}

const getColor = (estado: string) => {
  if (estado === 'Recibido') return '#ef4444';
  if (estado === 'En proceso') return '#f97316';
  if (estado === 'Solucionado') return '#22c55e';
  return '#6b7280';
};

// Función para extraer coordenadas aunque vengan como texto "SRID=4326;POINT(lng lat)"
const getCoordinates = (inc: Incidencia): [number, number] | null => {
  if (inc.geometry?.coordinates) {
    const [lng, lat] = inc.geometry.coordinates;
    return [lat, lng];
  }
  if (inc.ubicacion && inc.ubicacion.includes('POINT')) {
    const match = inc.ubicacion.match(/POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)/);
    if (match) {
      const lng = parseFloat(match[1]);
      const lat = parseFloat(match[2]);
      return [lat, lng];
    }
  }
  return null;
};

export default function MapaIncidencias({ data }: { data: Incidencia[] }) {
  // Filtrar solo las que tienen coordenadas válidas
  const validIncidencias = data.filter(getCoordinates);

  return (
    <MapContainer center={[-4.0085, -79.2239]} zoom={13} className="h-[500px] w-full rounded-lg z-0">
      <TileLayer url={process.env.NEXT_PUBLIC_TILE_URL || 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'} />
      
      {validIncidencias.map((inc) => {
        const coords = getCoordinates(inc);
        if (!coords) return null;
        
        const color = getColor(inc.estado);
        const customIcon = L.divIcon({
          className: 'custom-div-icon',
          html: `<div style="background-color:${color}; width:16px; height:16px; border-radius:50%; border:2px solid white; box-shadow: 0 0 4px rgba(0,0,0,0.5);"></div>`,
          iconSize: [16, 16],
          iconAnchor: [8, 8],
        });

        return (
          <Marker key={inc.id} position={coords} icon={customIcon}>
            <Popup>
              <b>{inc.categoria}</b><br />
              {inc.descripcion || 'Sin descripción'}<br />
              <i>Estado: {inc.estado}</i>
            </Popup>
          </Marker>
        );
      })}
    </MapContainer>
  );
}