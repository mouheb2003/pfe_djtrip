import { Outlet } from 'react-router';
import { lazy, Suspense } from 'react';

import { CONFIG } from 'src/global-config';
import { DashboardLayout } from 'src/layouts/dashboard';

import { LoadingScreen } from 'src/components/loading-screen';

import { AuthGuard } from 'src/auth/guard';

// ----------------------------------------------------------------------

const HomePage = lazy(() => import('src/pages/dashboard/Home'));
const IndexPage = lazy(() => import('src/pages/dashboard/Page1'));
const LieuxDetailsPage = lazy(() => import('src/pages/dashboard/LieuxDetails'));
const ActivitiesPage = lazy(() => import('src/pages/dashboard/Activities'));
const PublicationsPage = lazy(() => import('src/pages/dashboard/Publications'));
const MessagesPage = lazy(() => import('src/pages/dashboard/Messages'));
const UsersPage = lazy(() => import('src/pages/dashboard/Users'));

// ----------------------------------------------------------------------

const dashboardLayout = () => (
  <DashboardLayout>
    <Suspense fallback={<LoadingScreen />}>
      <Outlet />
    </Suspense>
  </DashboardLayout>
);

export const dashboardRoutes = [
  {
    path: 'dashboard',
    element: CONFIG.auth.skip ? dashboardLayout() : <AuthGuard>{dashboardLayout()}</AuthGuard>,
    children: [
      { element: <HomePage />, index: true },
      { path: 'lieux', element: <IndexPage /> },
      { path: 'lieux/:id', element: <LieuxDetailsPage /> },
      { path: 'activites', element: <ActivitiesPage /> },
      { path: 'two', element: <ActivitiesPage /> },
      { path: 'publications', element: <PublicationsPage /> },
      { path: 'messages', element: <MessagesPage /> },
      { path: 'three', element: <UsersPage /> },
      {
        path: 'group',
        children: [

        ],
      },
    ],
  },
];
