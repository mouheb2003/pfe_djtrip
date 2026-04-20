import { Navigate } from 'react-router-dom';

import { paths } from 'src/routes/paths';
import { usePathname } from 'src/routes/hooks';

import { CONFIG } from 'src/global-config';

import { SplashScreen } from 'src/components/loading-screen';

import { useAuthContext } from '../hooks';

// ----------------------------------------------------------------------

const signInPaths = {
  jwt: paths.auth.jwt.signIn,
  auth0: paths.auth.auth0.signIn,
  amplify: paths.auth.amplify.signIn,
  firebase: paths.auth.firebase.signIn,
  supabase: paths.auth.supabase.signIn,
};

export function AuthGuard({ children }) {
  const pathname = usePathname();

  const { authenticated, loading } = useAuthContext();

  const createRedirectPath = (currentPath) => {
    const queryString = new URLSearchParams({ returnTo: pathname }).toString();
    return `${currentPath}?${queryString}`;
  };

  if (loading) {
    return <SplashScreen />;
  }

  if (!authenticated) {
    const { method } = CONFIG.auth;
    const signInPath = signInPaths[method];
    const redirectPath = createRedirectPath(signInPath);

    return <Navigate to={redirectPath} replace />;
  }

  return <>{children}</>;
}
