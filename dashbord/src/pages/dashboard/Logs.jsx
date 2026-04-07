import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { LogsView } from 'src/sections/PageLogs';

const metadata = { title: `Logs | Dashboard - ${CONFIG.appName}` };

export default function LogsPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <LogsView />
    </>
  );
}
