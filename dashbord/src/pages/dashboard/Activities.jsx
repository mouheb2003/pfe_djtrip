import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { ActivitiesView } from 'src/sections/PageActivities';

const metadata = { title: `Activités | Dashboard - ${CONFIG.appName}` };

export default function ActivitiesPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <ActivitiesView />
    </>
  );
}
