'use client';

import { FormEvent, useState } from 'react';

export function SetPasswordForm({ csrf }: { csrf: string }) {
  const [error, setError] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    const form = new FormData(event.currentTarget);
    const response = await fetch('/auth/set-password', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-honor-csrf': csrf },
      body: JSON.stringify({ password: form.get('password') }),
    });
    if (response.status === 303 || response.ok) {
      window.location.assign('/app');
      return;
    }
    setError('Password update failed.');
  }
  return (
    <form onSubmit={submit}>
      <label>New password<input name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required /></label>
      {error ? <p className="error" role="alert">{error}</p> : null}
      <button type="submit">Save password</button>
    </form>
  );
}
