'use client';

import { MapContainer, TileLayer, Marker } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

export default function MiniMapa({ lat, lng }: { lat: number; lng: number; color?: string }) {
  return (
    <MapContainer
      center={[lat, lng]}
      zoom={16}
      dragging={false}
      scrollWheelZoom={false}
      doubleClickZoom={false}
      zoomControl={false}
      className="h-[180px] w-full"
    >
      <TileLayer
        url={process.env.NEXT_PUBLIC_TILE_URL || 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'}
        className="map-tiles-dark"
      />
      <Marker position={[lat, lng]} />
    </MapContainer>
  );
}