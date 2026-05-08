import Box from '@mui/material/Box';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';

export function PageHeader({ title }) {
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
    </Box>
  );
}
