import type { KnipConfig } from 'knip';

const config: KnipConfig = {
  entry: [
    'src/App.tsx',
    'api/*.ts',
    'api/**/*.ts',
    'tests/**/*.ts',
  ],
  project: [
    'src/**/*.ts',
    'src/**/*.tsx',
    'api/**/*.ts',
    'tests/**/*.ts',
  ],
};

export default config;
