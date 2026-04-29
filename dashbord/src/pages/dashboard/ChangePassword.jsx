import { Helmet } from 'react-helmet-async';
import { useState } from 'react';
import { useRouter } from 'src/routes/hooks';
import axios, { endpoints } from 'src/lib/axios';
import { CONFIG } from 'src/global-config';

import { Container, Typography, Stack, TextField, Button, Alert, Box, Card } from '@mui/material';

const metadata = { title: `Change Password | Dashboard - ${CONFIG.appName}` };

export default function ChangePasswordPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess(false);

    if (!formData.currentPassword || !formData.newPassword || !formData.confirmPassword) {
      setError('Please fill in all fields');
      return;
    }

    if (formData.newPassword !== formData.confirmPassword) {
      setError('New password and confirm password do not match');
      return;
    }

    if (formData.newPassword.length > 8) {
      setError('Password must be at most 8 characters long');
      return;
    }

    try {
      setLoading(true);
      await axios.put(endpoints.auth.changePassword, {
        currentPassword: formData.currentPassword,
        newPassword: formData.newPassword,
      });
      setSuccess(true);
      setFormData({ currentPassword: '', newPassword: '', confirmPassword: '' });
      setTimeout(() => {
        router.push('/dashboard');
      }, 2000);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to change password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <Container maxWidth="sm">
        <Stack spacing={3} sx={{ mt: 5 }}>
          <Typography variant="h4">Change Password</Typography>

          <Card sx={{ p: 3 }}>
            <Box component="form" onSubmit={handleSubmit}>
              <Stack spacing={3}>
                {error && (
                  <Alert severity="error" onClose={() => setError('')}>
                    {error}
                  </Alert>
                )}

                {success && (
                  <Alert severity="success" onClose={() => setSuccess(false)}>
                    Password changed successfully! Redirecting...
                  </Alert>
                )}

                <TextField
                  fullWidth
                  name="currentPassword"
                  label="Current Password"
                  type="password"
                  value={formData.currentPassword}
                  onChange={handleChange}
                  required
                />

                <TextField
                  fullWidth
                  name="newPassword"
                  label="New Password"
                  type="password"
                  value={formData.newPassword}
                  onChange={handleChange}
                  required
                />

                <TextField
                  fullWidth
                  name="confirmPassword"
                  label="Confirm New Password"
                  type="password"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  required
                />

                <Button
                  fullWidth
                  size="large"
                  type="submit"
                  variant="contained"
                  disabled={loading}
                >
                  {loading ? 'Changing...' : 'Change Password'}
                </Button>

                <Button
                  fullWidth
                  size="large"
                  variant="outlined"
                  onClick={() => router.push('/dashboard')}
                  disabled={loading}
                >
                  Cancel
                </Button>
              </Stack>
            </Box>
          </Card>
        </Stack>
      </Container>
    </>
  );
}
