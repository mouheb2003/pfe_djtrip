import { useState, useMemo, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Alert from '@mui/material/Alert';
import Stack from '@mui/material/Stack';
import Button from '@mui/material/Button';
import Divider from '@mui/material/Divider';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import CircularProgress from '@mui/material/CircularProgress';

import { paths } from 'src/routes/paths';
import { useRouter } from 'src/routes/hooks';
import { DashboardContent } from 'src/layouts/dashboard';
import { useAuthContext } from 'src/auth/hooks';
import { setSession } from 'src/auth/context/jwt/utils';
import { toast } from 'src/components/snackbar';
import {
  updateMyProfile,
  changeMyPassword,
  logoutCurrentUser,
} from 'src/Controller/actions';

export function SettingsView({ sx }) {
  const router = useRouter();
  const { user, checkUserSession } = useAuthContext();

  const [profileLoading, setProfileLoading] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [logoutLoading, setLogoutLoading] = useState(false);
  const [profileError, setProfileError] = useState('');
  const [passwordError, setPasswordError] = useState('');

  const [fullname, setFullname] = useState(user?.fullname ?? '');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const canUpdateProfile = useMemo(() => {
    const current = String(user?.fullname ?? '').trim();
    return String(fullname).trim() && String(fullname).trim() !== current;
  }, [fullname, user?.fullname]);

  const canUpdatePassword = useMemo(
    () =>
      currentPassword.trim() &&
      newPassword.trim() &&
      confirmPassword.trim() &&
      newPassword.trim().length >= 8,
    [confirmPassword, currentPassword, newPassword]
  );

  const handleUpdateProfile = useCallback(async () => {
    setProfileError('');

    const trimmedFullname = String(fullname ?? '').trim();
    if (!trimmedFullname) {
      setProfileError('Le username (nom complet) est obligatoire.');
      return;
    }

    try {
      setProfileLoading(true);
      await updateMyProfile({ fullname: trimmedFullname });
      await checkUserSession();
      toast.success('Username admin mis a jour.');
    } catch (error) {
      const message = error?.message || error?.error || 'Echec de mise a jour du username.';
      setProfileError(message);
      toast.error(message);
    } finally {
      setProfileLoading(false);
    }
  }, [checkUserSession, fullname]);

  const handleChangePassword = useCallback(async () => {
    setPasswordError('');

    if (newPassword !== confirmPassword) {
      setPasswordError('La confirmation du mot de passe ne correspond pas.');
      return;
    }

    if (newPassword.trim().length < 8) {
      setPasswordError('Le nouveau mot de passe doit contenir au moins 8 caracteres.');
      return;
    }

    try {
      setPasswordLoading(true);
      await changeMyPassword(currentPassword.trim(), newPassword.trim());
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      toast.success('Mot de passe modifie avec succes.');
    } catch (error) {
      const message = error?.message || error?.error || 'Echec de changement du mot de passe.';
      setPasswordError(message);
      toast.error(message);
    } finally {
      setPasswordLoading(false);
    }
  }, [confirmPassword, currentPassword, newPassword]);

  const handleLogout = useCallback(async () => {
    try {
      setLogoutLoading(true);
      await logoutCurrentUser();
    } catch {
      // Continue logout locally even if backend call fails.
    } finally {
      await setSession(null);
      setLogoutLoading(false);
      router.replace(paths.auth.jwt.signIn);
    }
  }, [router]);

  return (
    <DashboardContent maxWidth="md" sx={sx}>
      <Stack spacing={2}>
        <Typography variant="h4">Settings Admin</Typography>

        <Card sx={{ p: 3 }}>
          <Stack spacing={2}>
            <Typography variant="h6">Profil admin</Typography>
            <Typography variant="body2" color="text.secondary">
              Modifiez le username de l&apos;admin (champ nom complet).
            </Typography>

            {!!profileError && <Alert severity="error">{profileError}</Alert>}

            <TextField
              label="Username admin"
              value={fullname}
              onChange={(event) => setFullname(event.target.value)}
              disabled={profileLoading}
              fullWidth
            />

            <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
              <Button
                variant="contained"
                onClick={handleUpdateProfile}
                disabled={!canUpdateProfile || profileLoading}
                startIcon={profileLoading ? <CircularProgress size={16} color="inherit" /> : null}
              >
                Enregistrer username
              </Button>
            </Box>
          </Stack>
        </Card>

        <Card sx={{ p: 3 }}>
          <Stack spacing={2}>
            <Typography variant="h6">Securite</Typography>
            <Typography variant="body2" color="text.secondary">
              Changez le mot de passe admin.
            </Typography>

            {!!passwordError && <Alert severity="error">{passwordError}</Alert>}

            <TextField
              type="password"
              label="Mot de passe actuel"
              value={currentPassword}
              onChange={(event) => setCurrentPassword(event.target.value)}
              disabled={passwordLoading}
              fullWidth
            />
            <TextField
              type="password"
              label="Nouveau mot de passe"
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              disabled={passwordLoading}
              fullWidth
              helperText="Minimum 8 caracteres"
            />
            <TextField
              type="password"
              label="Confirmer le nouveau mot de passe"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              disabled={passwordLoading}
              fullWidth
            />

            <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
              <Button
                variant="contained"
                onClick={handleChangePassword}
                disabled={!canUpdatePassword || passwordLoading}
                startIcon={passwordLoading ? <CircularProgress size={16} color="inherit" /> : null}
              >
                Changer mot de passe
              </Button>
            </Box>
          </Stack>
        </Card>

        <Card sx={{ p: 3 }}>
          <Stack spacing={2}>
            <Typography variant="h6">Session</Typography>
            <Typography variant="body2" color="text.secondary">
              Deconnexion immediate du compte admin.
            </Typography>
            <Divider />
            <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
              <Button
                color="error"
                variant="contained"
                onClick={handleLogout}
                disabled={logoutLoading}
                startIcon={logoutLoading ? <CircularProgress size={16} color="inherit" /> : null}
              >
                Se deconnecter
              </Button>
            </Box>
          </Stack>
        </Card>
      </Stack>
    </DashboardContent>
  );
}
