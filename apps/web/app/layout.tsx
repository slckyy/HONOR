import './globals.css';
import type { Metadata, Viewport } from 'next';
import { NetworkStatus } from '@/components/network-status';
import { PwaBoot } from '@/components/pwa-boot';

export const metadata: Metadata = {
  title: 'HONOR',
  description: 'HONOR controlled production pilot foundation',
  appleWebApp: { capable: true, statusBarStyle: 'black-translucent', title: 'HONOR' },
};
export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#0b0c0f',
};
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <PwaBoot />
        <NetworkStatus />
        <main className="shell">{children}</main>
      </body>
    </html>
  );
}
