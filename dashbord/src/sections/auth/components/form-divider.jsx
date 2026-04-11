import Divider from '@mui/material/Divider';

// ----------------------------------------------------------------------

export function FormDivider({ sx, label }) {
  return (
    <Divider
      sx={[
        {
          my: 3,
          typography: 'body2',
          color: 'text.disabled',
          fontWeight: 'fontWeightMedium',
          '&::before, &::after': { borderTopStyle: 'dashed' },
        },
        ...(Array.isArray(sx) ? sx : [sx]),
      ]}
    >
      {label}
    </Divider>
  );
}
