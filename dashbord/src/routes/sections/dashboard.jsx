import { Outlet } from 'react-router-dom';

import { CONFIG } from 'src/global-config';
import { DashboardLayout } from 'src/layouts/dashboard';

import { AuthGuard } from 'src/auth/guard';

// ----------------------------------------------------------------------

import HomePage from 'src/pages/dashboard/Home';
import IndexPage from 'src/pages/dashboard/Page1';
import LieuxDetailsPage from 'src/pages/dashboard/LieuxDetails';
import ActivitiesPage from 'src/pages/dashboard/Activities';
import PublicationsPage from 'src/pages/dashboard/Publications';
import MessagesPage from 'src/pages/dashboard/Messages';
import UsersPage from 'src/pages/dashboard/Users';
import LogsPage from 'src/pages/dashboard/Logs';
import AppealsPage from 'src/pages/dashboard/Appeals';
import ApprovalsPage from 'src/pages/dashboard/Approvals';
import PaymentsPage from 'src/pages/dashboard/Payments';
import ChangePasswordPage from 'src/pages/dashboard/ChangePassword';

// ----------------------------------------------------------------------

function DashboardOutlet() {
  return (
  <DashboardLayout>
    <Outlet />
  </DashboardLayout>
  );
}

function DashboardRouteElement() {
  if (CONFIG.auth.skip) {
    return <DashboardOutlet />;
  }

  return (
    <AuthGuard>
      <DashboardOutlet />
    </AuthGuard>
  );
}

export const dashboardRoutes = [
  {
    path: 'dashboard',
    element: <DashboardRouteElement />,
    children: [
      { element: <HomePage />, index: true },
      { path: 'lieux', element: <IndexPage /> },
      { path: 'lieux/:id', element: <LieuxDetailsPage /> },
      { path: 'activites', element: <ActivitiesPage /> },
      { path: 'two', element: <ActivitiesPage /> },
      { path: 'publications', element: <PublicationsPage /> },
      { path: 'messages', element: <MessagesPage /> },
      { path: 'logs', element: <LogsPage /> },
      { path: 'three', element: <UsersPage /> },
      { path: 'appeals', element: <AppealsPage /> },
      { path: 'approvals', element: <ApprovalsPage /> },
      { path: 'payments', element: <PaymentsPage /> },
      { path: 'change-password', element: <ChangePasswordPage /> },
    ],
  },
];
