import { Navigate } from 'react-router-dom';

import { useSearchParams } from 'src/routes/hooks';

import { CONFIG } from 'src/global-config';

import { SplashScreen } from 'src/components/loading-screen';

import { useAuthContext } from '../hooks';

// ----------------------------------------------------------------------

export function GuestGuard({ children }) {
  const searchParams = useSearchParams();
  const returnTo = searchParams.get('returnTo') || CONFIG.auth.redirectPath;

  const { loading, authenticated } = useAuthContext();

  if (loading) {
    return <SplashScreen />;
  }

  if (authenticated) {
    return <Navigate to={returnTo} replace />;
  }

  return <>{children}</>;
}
