import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { HomeFeedView } from 'src/sections/HomeFeed';

const metadata = { title: `Home | Dashboard - ${CONFIG.appName}` };

export default function HomePage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <HomeFeedView />
    </>
  );
}
