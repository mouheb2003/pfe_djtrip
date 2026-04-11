import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { PublicationsView } from 'src/sections/PagePublications';

const metadata = { title: `Publications | Dashboard - ${CONFIG.appName}` };

export default function PublicationsPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <PublicationsView />
    </>
  );
}
