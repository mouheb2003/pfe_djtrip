import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { MessagesView } from 'src/sections/PageMessages';

const metadata = { title: `Messagerie | Dashboard - ${CONFIG.appName}` };

export default function MessagesPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <MessagesView />
    </>
  );
}
