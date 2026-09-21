'use client';

import { FormEvent, useState } from 'react';

export function LoginForm({ csrf }: { csrf: string }) {
  const [error, setError] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    const form = new FormData(event.currentTarget);
    const response = await fetch('/auth/login', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-honor-csrf': csrf },
      body: JSON.stringify({ email: form.get('email'), password: form.get('password') }),
    });
    if (response.status === 303 || response.ok) {
      window.location.assign('/app');
      return;
    }
    setError('Sign-in failed.');
  }
  return (
    <form onSubmit={submit}>
      <label>Email<input name="email" type="email" autoComplete="username" required /></label>
      <label>Password<input name="password" type="password" autoComplete="current-password" required /></label>
      {error ? <p className="error" role="alert">{error}</p> : null}
      <button type="submit">Sign in</button>
    </form>
  );
}
