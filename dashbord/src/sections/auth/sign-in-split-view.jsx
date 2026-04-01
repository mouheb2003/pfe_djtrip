import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

import Link from '@mui/material/Link';

import { paths } from 'src/routes/paths';
import { RouterLink } from 'src/routes/components';
import { useRouter } from 'src/routes/hooks';

import { Logo } from 'src/components/logo';
import { Form } from 'src/components/hook-form';

import { login } from 'src/Controller/Api';

import { FormHead } from './components/form-head';
import { SignInSchema } from './components/schema';
import { SignInForm } from './components/sign-in-form';
import { FormSocials } from './components/form-socials';
import { FormDivider } from './components/form-divider';

// ----------------------------------------------------------------------

export function SignInSplitView() {
  const router = useRouter();

  const defaultValues = {
    email: '',
    password: '',
  };

  const methods = useForm({
    resolver: zodResolver(SignInSchema),
    defaultValues,
  });

  const { reset, handleSubmit } = methods;

  const GOOGLE_AUTH_URL = 'http://localhost:5000/api/users/google';

  const handleGoogleSignIn = () => {
    // Redirect to backend Google auth endpoint
    window.location.assign(GOOGLE_AUTH_URL);
  };

  const onSubmit = handleSubmit(async (data) => {
    try {
      await login(data.email, data.password);
      reset();
      router.push(paths.travel.root);
    } catch (error) {
      console.error(error);
    }
  });

  return (
    <>
      <Logo sx={{ alignSelf: { xs: 'center', md: 'flex-start' } }} />

      <FormHead
        title="Sign in"
        description={
          <>
            {`Don’t have an account? `}
            <Link component={RouterLink} href={paths.split.signUp} variant="subtitle2">
              Get started
            </Link>
          </>
        }
        sx={{ mt: { xs: 5, md: 8 }, textAlign: { xs: 'center', md: 'left' } }}
      />

      <FormSocials signInWithGoogle={handleGoogleSignIn} />

      <FormDivider label="OR" />

      <Form methods={methods} onSubmit={onSubmit}>
        <SignInForm />
      </Form>

      {/* Note: après Google sign-in, le backend redirige vers /?user=... et MainLayout le parse/stocke. */}
    </>
  );
}
