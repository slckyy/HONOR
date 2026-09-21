import { cookies } from 'next/headers';
import { CSRF_COOKIE } from '@/lib/csrf';
import { LoginForm } from '@/components/login-form';
import { RecoverForm } from '@/components/recover-form';

export default async function Login() {
  const csrf = (await cookies()).get(CSRF_COOKIE)?.value ?? '';
  return (
    <section className="card hero">
      <p className="eyebrow">Private owner access</p>
      <h1>Sign in to HONOR</h1>
      <LoginForm csrf={csrf} />
      <RecoverForm csrf={csrf} />
    </section>
  );
}
