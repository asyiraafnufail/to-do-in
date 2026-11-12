import Link from 'next/link';
import './globals.css';

export const metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://todoin.id'),
  title: {
    default: 'todoin.id — Cerita Perjalanan, To-Do Wisata, & Layanan Lokal Terverifikasi',
    template: '%s | todoin.id',
  },
  description:
    'Platform komunitas perjalanan Indonesia berbasis validasi Live GPS, perencana aktivitas My To-Do, serta sewa motor/mobil, open trip, dan homestay terpercaya.',
  openGraph: {
    siteName: 'todoin.id',
    type: 'website',
    locale: 'id_ID',
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="id">
      <body>
        <header>
          <div className="nav-container">
            <Link href="/" className="brand">todoin.id</Link>
            <a href="todoin://open" className="btn-open-app">Buka di Aplikasi</a>
          </div>
        </header>
        <main>{children}</main>
        <footer>
          <p>© {new Date().getFullYear()} todoin.id • Komunitas Perjalanan &amp; Rekomendasi To-Do Wisata Indonesia</p>
        </footer>
      </body>
    </html>
  );
}
