import { Helmet } from 'react-helmet-async';

import { CONFIG } from 'src/global-config';

import { PaymentsView } from 'src/sections/PagePayments';

const metadata = { title: `Payments | Dashboard - ${CONFIG.appName}` };

export default function PaymentsPage() {
  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <PaymentsView />
    </>
  );
}
