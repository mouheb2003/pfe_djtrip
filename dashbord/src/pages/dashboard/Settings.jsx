import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';
import { SettingsView } from 'src/sections/PageSettings';

const metadata = { title: `Settings | Dashboard - ${CONFIG.appName}` };

export default function SettingsPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <SettingsView />
    </>
  );
}
