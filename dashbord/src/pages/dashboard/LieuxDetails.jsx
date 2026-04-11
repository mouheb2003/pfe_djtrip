import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';
import { LieuxDetailsView } from 'src/sections/Page1/LieuxDetailsView';

const metadata = { title: `Details lieu | Dashboard - ${CONFIG.appName}` };

export default function LieuxDetailsPage() {
  return (
    <>
      <Helmet>
        <title> {metadata.title}</title>
      </Helmet>

      <LieuxDetailsView />
    </>
  );
}
