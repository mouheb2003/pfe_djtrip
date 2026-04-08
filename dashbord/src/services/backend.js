const BACKEND_MODE_STORAGE_KEY = 'djtrip-backend-mode';

const normalizeMode = (value) => (value === 'dev' ? 'dev' : 'prod');

const ensureScheme = (url) => {
  const value = String(url ?? '').trim();

  if (!value) return value;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  return `http://${value}`;
};

const BACKEND_URLS = {
  dev: ensureScheme(
    import.meta.env.VITE_DEV_SERVER_URL ??
      import.meta.env.VITE_API_BASE_URL ??
      'http://localhost:3000'
  ),
  prod: ensureScheme(
    import.meta.env.VITE_PROD_SERVER_URL ??
      import.meta.env.VITE_SERVER_URL ??
      'https://backdjtrip.onrender.com'
  ),
};

export const BACKEND_MODES = [
  {
    value: 'dev',
    label: 'Dev',
    description: 'Local backend',
  },
  {
    value: 'prod',
    label: 'Prod',
    description: 'Hosted backend',
  },
];

export function getBackendMode() {
  if (typeof window === 'undefined') {
    return normalizeMode(import.meta.env.VITE_BACKEND_MODE ?? 'prod');
  }

  return normalizeMode(
    window.localStorage.getItem(BACKEND_MODE_STORAGE_KEY) ??
      import.meta.env.VITE_BACKEND_MODE ??
      'prod'
  );
}

export function setBackendMode(mode) {
  const nextMode = normalizeMode(mode);

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(BACKEND_MODE_STORAGE_KEY, nextMode);
  }

  return nextMode;
}

export function getBackendUrl(mode = getBackendMode()) {
  return BACKEND_URLS[normalizeMode(mode)];
}

export function getApiPrefix() {
  return '/api/v1';
}

export function buildApiPath(path) {
  return `${getApiPrefix()}${path.startsWith('/') ? path : `/${path}`}`;
}
