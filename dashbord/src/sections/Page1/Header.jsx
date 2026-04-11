import Box from '@mui/material/Box';
import Stack from '@mui/material/Stack';
import Tooltip from '@mui/material/Tooltip';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import { useTheme, alpha } from '@mui/material/styles';

import { varAlpha } from 'minimal-shared/utils';
import { Iconify } from 'src/components/iconify';

export function PageHeader({ title, onAdd }) {
  const theme = useTheme();

  const primaryMainChannel = theme?.vars?.palette?.primary?.mainChannel;
  const fabShadow =
    typeof primaryMainChannel === 'string'
      ? `0 8px 16px ${varAlpha(primaryMainChannel, 0.24)}`
      : `0 8px 16px ${alpha(theme.palette.primary.main, 0.24)}`;

  return (
    <Box
      sx={{
        mb: 3,
        display: 'flex',
        alignItems: 'flex-start',
        justifyContent: 'space-between',
      }}
    >
      <Stack spacing={1}>
        <Typography variant="h4">{title}</Typography>
      </Stack>

      <Tooltip title="Ajouter">
        <IconButton
          onClick={onAdd}
          sx={{
            width: 40,
            height: 40,
            bgcolor: 'primary.main',
            color: 'primary.contrastText',
            boxShadow: fabShadow,
            '&:hover': { bgcolor: 'primary.dark' },
          }}
        >
          <Iconify icon="mingcute:add-line" />
        </IconButton>
      </Tooltip>
    </Box>
  );
}
