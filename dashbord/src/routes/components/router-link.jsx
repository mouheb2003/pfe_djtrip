import { forwardRef } from 'react';
import { Link } from 'react-router-dom';

export const RouterLink = forwardRef(({ href, to, ...other }, ref) => (
  <Link ref={ref} to={to ?? href} {...other} />
));
