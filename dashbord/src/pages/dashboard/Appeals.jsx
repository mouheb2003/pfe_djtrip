import { Helmet } from 'react-helmet-async';
import { CONFIG } from 'src/global-config';
import { AppealsView } from 'src/sections/PageAppeals';

const metadata = { title: `Appeals | Dashboard - ${CONFIG.appName}` };

export default function AppealsPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <AppealsView />
    </>
  );
}
