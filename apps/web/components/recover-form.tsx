'use client';

import { FormEvent, useState } from 'react';

export function RecoverForm({ csrf }: { csrf: string }) {
  const [message, setMessage] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    await fetch('/auth/recover', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-honor-csrf': csrf },
      body: JSON.stringify({ email: form.get('email') }),
    }).catch(() => undefined);
    // Frozen anti-enumeration behavior: the browser shows the same response regardless
    // of account existence or provider detail.
    setMessage('If the address is eligible, recovery instructions will be sent.');
  }
  return (
    <details>
      <summary>Forgot password?</summary>
      <form onSubmit={submit}>
        <label>Owner email<input name="email" type="email" autoComplete="email" required /></label>
        <button type="submit">Send recovery instructions</button>
        {message ? <p className="muted" role="status">{message}</p> : null}
      </form>
    </details>
  );
}
