'use client';

import { useEffect, useState } from 'react';

export function NetworkStatus() {
  const [online, setOnline] = useState(true);
  useEffect(() => {
    const update = () => setOnline(navigator.onLine);
    update();
    window.addEventListener('online', update);
    window.addEventListener('offline', update);
    return () => {
      window.removeEventListener('online', update);
      window.removeEventListener('offline', update);
    };
  }, []);
  if (online) return null;
  return (
    <div className="network-banner" role="status" aria-live="polite">
      Offline — read-only shell only. HONOR does not queue business mutations in the browser.
    </div>
  );
}
