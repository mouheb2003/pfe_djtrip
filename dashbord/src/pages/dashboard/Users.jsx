import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { UsersView } from 'src/sections/PageUsers';

const metadata = { title: `Utilisateurs | Dashboard - ${CONFIG.appName}` };

export default function UsersPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <UsersView />
    </>
  );
}
