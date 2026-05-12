import { Outlet } from 'react-router-dom';

import { CONFIG } from 'src/global-config';
import HomePage from 'src/pages/dashboard/Home';
import LogsPage from 'src/pages/dashboard/Logs';
import IndexPage from 'src/pages/dashboard/Page1';
import UsersPage from 'src/pages/dashboard/Users';
import FacteursPage from 'src/pages/dashboard/Facteurs';
import AddLieuPage from 'src/pages/dashboard/AddLieu';
import AppealsPage from 'src/pages/dashboard/Appeals';
import MessagesPage from 'src/pages/dashboard/Messages';
import PaymentsPage from 'src/pages/dashboard/Payments';
import { DashboardLayout } from 'src/layouts/dashboard';
import ApprovalsPage from 'src/pages/dashboard/Approvals';
import ActivitiesPage from 'src/pages/dashboard/Activities';
import LieuxDetailsPage from 'src/pages/dashboard/LieuxDetails';
import PublicationsPage from 'src/pages/dashboard/Publications';
import ChangePasswordPage from 'src/pages/dashboard/ChangePassword';

import { AuthGuard } from 'src/auth/guard';

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
      { path: 'lieux/add', element: <AddLieuPage /> },
      { path: 'lieux/:id', element: <LieuxDetailsPage /> },
      { path: 'activites', element: <ActivitiesPage /> },
      { path: 'two', element: <ActivitiesPage /> },
      { path: 'publications', element: <PublicationsPage /> },
      { path: 'messages', element: <MessagesPage /> },
      { path: 'logs', element: <LogsPage /> },
      { path: 'users', element: <UsersPage /> },
      { path: 'facteurs', element: <FacteursPage /> },
      { path: 'appeals', element: <AppealsPage /> },
      { path: 'approvals', element: <ApprovalsPage /> },
      { path: 'payments', element: <PaymentsPage /> },
      { path: 'change-password', element: <ChangePasswordPage /> },
    ],
  },
];
