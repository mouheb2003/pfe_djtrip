# Dashboard Backend Mode Guide

This dashboard can switch between two API targets:

- `dev`: local backend for development
- `prod`: hosted backend for production

## How to switch

Open the dashboard, then open the **Settings** drawer from the gear icon in the top bar.

In the new **Backend** section, select:

- **Dev** to use the local API
- **Prod** to use the hosted API at `https://backdjtrip.onrender.com`

The selected mode is saved in `localStorage`, so it stays active after refresh.

## Environment variables

The backend URL can also be controlled with environment variables:

- `VITE_BACKEND_MODE`: default mode used when the app starts (`dev` or `prod`)
- `VITE_DEV_SERVER_URL`: local backend URL for development
- `VITE_PROD_SERVER_URL`: hosted backend URL for production
- `VITE_API_BASE_URL`: fallback local API URL for older setups
- `VITE_SERVER_URL`: fallback hosted API URL for older setups

Examples:

```env
VITE_BACKEND_MODE=prod
VITE_DEV_SERVER_URL=http://192.168.1.50:3000
VITE_PROD_SERVER_URL=https://backdjtrip.onrender.com
```

## API prefix

All dashboard requests go through the `/api/v1` prefix.

Example:

- `/api/v1/users`
- `/api/v1/activites/admin`
- `/api/v1/messages/conversations`

## Notes

- Switch to `dev` when testing on a local backend.
- Switch to `prod` before shipping or testing against the hosted backend.
- If you change environment variables, restart the dashboard dev server.
