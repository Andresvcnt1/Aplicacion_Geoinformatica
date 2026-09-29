/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'geoincidenciasloja.duckdns.org',
        pathname: '/media/**',
      },
    ],
  },
};

module.exports = nextConfig;