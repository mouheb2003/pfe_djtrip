import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { BlankView } from 'src/sections/Page1';
import { LieuxMapExplorer } from 'src/sections/Page1/LieuxMapExplorer';

// ----------------------------------------------------------------------

const metadata = { title: `Lieux | Dashboard - ${CONFIG.appName}` };

export default function Page() {
  return (
    <>
      <Helmet>
        <title> {metadata.title}</title>
      </Helmet>

      <LieuxMapExplorer />

      <BlankView title="Lieux" />
    </>
  );
}
