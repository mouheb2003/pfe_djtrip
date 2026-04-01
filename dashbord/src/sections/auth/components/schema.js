import * as z from 'zod';

import { schemaUtils } from 'src/components/hook-form';

// ----------------------------------------------------------------------

export const SignInSchema = z.object({
  email: schemaUtils.email(),
  password: z
    .string()
    .min(1, { error: 'Password is required!' })
    .min(6, { error: 'Password must be at least 6 characters!' }),
});

// ----------------------------------------------------------------------

export const SignUpSchema = z
  .object({
    firstName: z.string().min(1, { error: 'First name is required!' }),
    lastName: z.string().min(1, { error: 'Last name is required!' }),
    email: schemaUtils.email(),
    code: z.string().optional(),
    password: z.string().optional(),
    confirmPassword: z.string().optional(),
  })
  .refine(
    (val) => {
      if (val.password && val.confirmPassword) {
        return val.password === val.confirmPassword;
      }
      return true;
    },
    {
      error: 'Passwords do not match!',
      path: ['confirmPassword'],
    }
  );

// ----------------------------------------------------------------------

export const ResetPasswordSchema = z.object({
  email: schemaUtils.email(),
});

// ----------------------------------------------------------------------

export const UpdatePasswordSchema = z
  .object({
    code: z
      .string()
      .min(1, { error: 'Code is required!' })
      .min(6, { error: 'Code must be at least 6 characters!' }),
    email: schemaUtils.email(),
    password: z
      .string()
      .min(1, { error: 'Password is required!' })
      .min(6, { error: 'Password must be at least 6 characters!' }),
    confirmPassword: z.string().min(1, { error: 'Confirm password is required!' }),
  })
  .refine((val) => val.password === val.confirmPassword, {
    error: 'Passwords do not match!',
    path: ['confirmPassword'],
  });

// ----------------------------------------------------------------------

export const VerifySchema = z.object({
  code: z
    .string()
    .min(1, { error: 'Code is required!' })
    .min(6, { error: 'Code must be at least 6 characters!' }),
});
