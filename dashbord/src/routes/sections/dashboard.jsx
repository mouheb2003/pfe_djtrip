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
const CommentsPage = lazy(() => import('src/sections/PageComments'));
const MessagesPage = lazy(() => import('src/pages/dashboard/Messages'));
const UsersPage = lazy(() => import('src/pages/dashboard/Users'));
const LogsPage = lazy(() => import('src/pages/dashboard/Logs'));
const SettingsPage = lazy(() => import('src/pages/dashboard/Settings'));
const AppealsPage = lazy(() => import('src/pages/dashboard/Appeals'));
const ApprovalsPage = lazy(() => import('src/pages/dashboard/Approvals'));
const NotificationsPage = lazy(() => import('src/pages/dashboard/Notifications'));

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
      { path: 'comments', element: <CommentsPage /> },
      { path: 'messages', element: <MessagesPage /> },
      { path: 'logs', element: <LogsPage /> },
      { path: 'settings', element: <SettingsPage /> },
      { path: 'three', element: <UsersPage /> },
      { path: 'notifications', element: <NotificationsPage /> },
      { path: 'appeals', element: <AppealsPage /> },
      { path: 'approvals', element: <ApprovalsPage /> },
    ],
  },
];
