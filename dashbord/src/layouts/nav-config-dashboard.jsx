import { paths } from 'src/routes/paths';

import { CONFIG } from 'src/global-config';

import { Label } from 'src/components/label';
import { SvgColor } from 'src/components/svg-color';

// ----------------------------------------------------------------------

const icon = (name) => <SvgColor src={`${CONFIG.assetsDir}/assets/icons/navbar/${name}.svg`} />;

const ICONS = {
  job: icon('ic-job'),
  blog: icon('ic-blog'),
  chat: icon('ic-chat'),
  mail: icon('ic-mail'),
  user: icon('ic-user'),
  file: icon('ic-file'),
  lock: icon('ic-lock'),
  tour: icon('ic-tour'),
  order: icon('ic-order'),
  label: icon('ic-label'),
  blank: icon('ic-blank'),
  kanban: icon('ic-kanban'),
  folder: icon('ic-folder'),
  course: icon('ic-course'),
  banking: icon('ic-banking'),
  booking: icon('ic-booking'),
  invoice: icon('ic-invoice'),
  product: icon('ic-product'),
  calendar: icon('ic-calendar'),
  disabled: icon('ic-disabled'),
  external: icon('ic-external'),
  menuItem: icon('ic-menu-item'),
  ecommerce: icon('ic-ecommerce'),
  analytics: icon('ic-analytics'),
  dashboard: icon('ic-dashboard'),
  parameter: icon('ic-parameter'),
};

// ----------------------------------------------------------------------

export const navData = [
  /**
   * CONTENT
   */
  /**
   * HOME
   */
  {
    items: [
      {
        title: 'Home',
        path: paths.dashboard.root,
        icon: ICONS.dashboard,
      },
    ],
  },
  /**
   * CONTENT
   */
  {
    subheader: 'CONTENT',
    items: [
      {
        title: 'Places',
        path: paths.dashboard.lieux.root,
        icon: ICONS.tour,
      },
      {
        title: 'Activities',
        path: paths.dashboard.activites,
        icon: ICONS.job,
      },
      {
        title: 'Publications',
        path: paths.dashboard.publications,
        icon: ICONS.blog,
      },
    ],
  },
  /**
   * USERS
   */
  {
    subheader: 'USERS',
    items: [
      {
        title: 'Users',
        path: paths.dashboard.three,
        icon: ICONS.user,
      },
      {
        title: 'Appeals',
        path: paths.dashboard.appeals,
        icon: ICONS.file,
      },
      {
        title: 'Approvals',
        path: paths.dashboard.approvals,
        icon: ICONS.user,
        info: <Label color="orange">5</Label>,
      },
    ],
  },
  /**
   * MESSAGING
   */
  {
    items: [
      {
        title: 'Messaging',
        path: paths.dashboard.messages,
        icon: ICONS.chat,
      },
      {
        title: 'Logs',
        path: paths.dashboard.logs,
        icon: ICONS.file,
      },
    ],
  },
  /**
   * PAYMENTS
   */
  {
    items: [
      {
        title: 'Payments',
        path: paths.dashboard.payments,
        icon: ICONS.invoice,
      },
    ],
  },
];
