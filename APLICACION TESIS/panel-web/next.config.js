/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false, // Necesario para evitar crashes de Leaflet en desarrollo
  async rewrites() {
    return [
      {
        source: '/api-proxy/:path*',
        destination: 'http://143.244.163.81/api/:path*', // Tu IP del droplet
      },
    ];
  },
};

module.exports = nextConfig