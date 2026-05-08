import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { FacteursView } from 'src/sections/PageFacteurs';

const metadata = { title: `Facteurs paiement | Dashboard - ${CONFIG.appName}` };

export default function FacteursPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <FacteursView />
    </>
  );
}
