import { readFileSync } from 'node:fs';
import { defineConfig } from 'vite';

// The version shown on the page comes from the app's pubspec.yaml.
const pubspec = readFileSync(new URL('../pubspec.yaml', import.meta.url), 'utf8');
const version = (pubspec.match(/^version:\s*([^+\s]+)/m) || [])[1] || 'dev';

export default defineConfig({
  base: './',
  define: {
    __APP_VERSION__: JSON.stringify(version),
  },
  server: {
    port: 5173,
    open: false,
  },
});
