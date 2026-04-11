import Box from '@mui/material/Box';
import IconButton from '@mui/material/IconButton';

import { Iconify } from 'src/components/iconify';

// ----------------------------------------------------------------------

export function FormSocials({
  sx,
  signInWithGoogle,
  signInWithGithub,
  singInWithGithub,
  signInWithTwitter,
  ...other
}) {
  const noop = () => {};
  const githubHandler = signInWithGithub ?? singInWithGithub ?? noop;

  return (
    <Box
      sx={[
        {
          gap: 1.5,
          display: 'flex',
          justifyContent: 'center',
        },
        ...(Array.isArray(sx) ? sx : [sx]),
      ]}
      {...other}
    >
      <IconButton
        aria-label="Sign in with Google"
        color="inherit"
        onClick={signInWithGoogle ?? noop}
      >
        <Iconify width={22} icon="socials:google" />
      </IconButton>
      <IconButton aria-label="Sign in with GitHub" color="inherit" onClick={githubHandler}>
        <Iconify width={22} icon="socials:github" />
      </IconButton>
      <IconButton
        aria-label="Sign in with Twitter"
        color="inherit"
        onClick={signInWithTwitter ?? noop}
      >
        <Iconify width={22} icon="socials:twitter" />
      </IconButton>
    </Box>
  );
}
