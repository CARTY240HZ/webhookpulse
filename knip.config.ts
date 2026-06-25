import type { KnipConfig } from 'knip';

const config: KnipConfig = {
  entry: [
    'src/main.tsx',
    'src/App.tsx',
    'api/*.ts',
    'api/**/*.ts',
    'tests/**/*.ts',
    'tests/**/*.tsx',
    'public/sw.js',
  ],
  project: [
    'src/**/*.ts',
    'src/**/*.tsx',
    'api/**/*.ts',
    'tests/**/*.ts',
    'tests/**/*.tsx',
  ],
  // Ignore config files that are loaded by tooling
  ignore: [
    'public/**',
    'dist/**',
    'docker-compose.yml',
    'Dockerfile',
    'nginx.conf',
    'vite.config.ts',
    'vitest.config.ts',
    'tailwind.config.js',
    'postcss.config.js',
  ],
  // Dependencies that are used implicitly or by Astro/Vite
  ignoreDependencies: [
    '@types/react',
    '@types/react-dom',
    'autoprefixer',
  ],
  // Ignore binaries that are used in scripts
  ignoreBinaries: [
    'vercel',
  ],
};

export default config;