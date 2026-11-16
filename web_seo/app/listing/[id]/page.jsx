import Link from 'next/link';
import { notFound } from 'next/navigation';
import { fetchListingById, getListingImageUrl } from '../../../lib/pb';

export const dynamic = 'force-dynamic';

function formatPrice(num) {
  if (typeof num !== 'number') return '0';
  return num.toLocaleString('id-ID');
}

function unitLabel(unit) {
  switch (unit) {
    case 'day':
      return '/ hari';
    case 'night':
      return '/ malam';
    case 'pax':
      return '/ orang';
    case 'month':
      return '/ bulan';
    default:
      return '';
  }
}

function typeLabel(type) {
  switch (type) {
    case 'vehicle':
      return 'Sewa Kendaraan';
    case 'open_trip':
      return 'Open Trip';
    case 'stay':
      return 'Homestay & Kos';
    default:
      return 'Layanan';
  }
}

export async function generateMetadata({ params }) {
  const listing = await fetchListingById(params.id);
  if (!listing) {
    return { title: 'Layanan Tidak Ditemukan' };
  }

  const owner = listing.expand?.owner;
  const ownerName = owner?.name || (owner?.username ? `@${owner.username}` : 'Local Host');
  const loc = [listing.city, listing.province].filter(Boolean).join(', ');
  const title = `${listing.title} — ${typeLabel(listing.type)}`;
  const description =
    (listing.description || '').replace(/\s+/g, ' ').trim().slice(0, 160) ||
    `${typeLabel(listing.type)} di ${loc || 'Indonesia'} oleh ${ownerName}. Rp${formatPrice(listing.price)} ${unitLabel(listing.price_unit)}.`;

  const ogImage =
    Array.isArray(listing.images) && listing.images.length > 0
      ? getListingImageUrl(listing, listing.images[0])
      : undefined;

  return {
    title,
    description,
    alternates: {
      canonical: `/listing/${encodeURIComponent(listing.id)}`,
    },
    openGraph: {
      title: `${title} — todoin.id`,
      description,
      type: 'website',
      url: `/listing/${encodeURIComponent(listing.id)}`,
      images: ogImage ? [{ url: ogImage }] : [],
    },
    twitter: {
      card: ogImage ? 'summary_large_image' : 'summary',
      title: `${title} — todoin.id`,
      description,
      images: ogImage ? [ogImage] : [],
    },
  };
}

export default async function ListingPage({ params }) {
  const listing = await fetchListingById(params.id);
  if (!listing) {
    notFound();
  }

  const owner = listing.expand?.owner;
  const ownerName = owner?.name || (owner?.username ? `@${owner.username}` : 'Local Host');
  const ownerWa = owner?.whatsapp || '';
  const loc = [listing.city, listing.province].filter(Boolean).join(', ');
  const images = Array.isArray(listing.images) ? listing.images : [];
  const specs = typeof listing.specs === 'object' && listing.specs ? listing.specs : {};

  const cleanWa = ownerWa.replace(/[^0-9]/g, '');
  const waMsg = encodeURIComponent(
    `Halo ${ownerName}, saya tertarik dengan layanan "${listing.title}" di todoin.id. Apakah masih tersedia?`
  );
  const waUrl = cleanWa ? `https://wa.me/${cleanWa}?text=${waMsg}` : '';

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: listing.title,
    description: (listing.description || '').slice(0, 160),
    image: images.map((img) => getListingImageUrl(listing, img)),
    offers: {
      '@type': 'Offer',
      price: listing.price,
      priceCurrency: 'IDR',
      availability: listing.is_available
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
    },
  };

  return (
    <article
      style={{
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 14,
        padding: 22,
      }}
    >
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
        <span
          style={{
            background: 'rgba(15, 118, 110, 0.1)',
            color: 'var(--primary)',
            padding: '4px 12px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 700,
          }}
        >
          {typeLabel(listing.type)}
        </span>
        <span
          style={{
            background: listing.is_available ? 'var(--gps-bg)' : 'rgba(239, 68, 68, 0.1)',
            color: listing.is_available ? 'var(--gps-fg)' : '#dc2626',
            padding: '4px 12px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 700,
          }}
        >
          {listing.is_available ? 'Tersedia' : 'Penuh'}
        </span>
      </div>

      <h1 style={{ fontSize: 24, fontWeight: 800, marginBottom: 8 }}>{listing.title}</h1>

      <p style={{ color: 'var(--text-secondary)', fontSize: 13.5, marginBottom: 16 }}>
        📍 {loc || 'Indonesia'}
      </p>

      {images.length > 0 && (
        <div style={{ display: 'flex', gap: 10, overflowX: 'auto', marginBottom: 20 }}>
          {images.map((img, i) => (
            <img
              key={i}
              src={getListingImageUrl(listing, img)}
              alt={`${listing.title} ${i + 1}`}
              style={{
                width: 260,
                height: 180,
                objectFit: 'cover',
                borderRadius: 10,
                flexShrink: 0,
              }}
            />
          ))}
        </div>
      )}

      <div
        style={{
          background: 'var(--bg)',
          padding: 14,
          borderRadius: 10,
          border: '1px solid var(--border)',
          marginBottom: 20,
        }}
      >
        <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Tarif Sewa / Biaya</div>
        <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--primary)', marginTop: 2 }}>
          Rp{formatPrice(listing.price)}{' '}
          <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)' }}>
            {unitLabel(listing.price_unit)}
          </span>
        </div>
      </div>

      {Object.keys(specs).length > 0 && (
        <div style={{ marginBottom: 20 }}>
          <h2 style={{ fontSize: 15, fontWeight: 700, marginBottom: 10 }}>Spesifikasi &amp; Fasilitas:</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 8 }}>
            {Object.entries(specs).map(([k, v]) => (
              <div
                key={k}
                style={{
                  padding: '8px 12px',
                  background: 'var(--bg)',
                  borderRadius: 8,
                  fontSize: 13,
                  border: '1px solid var(--border)',
                }}
              >
                <span style={{ color: 'var(--text-muted)' }}>{k}:</span> <strong>{String(v)}</strong>
              </div>
            ))}
          </div>
        </div>
      )}

      <div style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 15, fontWeight: 700, marginBottom: 8 }}>Deskripsi Layanan</h2>
        <div
          style={{ lineHeight: 1.7, fontSize: 14.5, whiteSpace: 'pre-line' }}
          dangerouslySetInnerHTML={{ __html: listing.description || '' }}
        />
      </div>

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 16,
          paddingTop: 16,
          borderTop: '1px solid var(--border)',
          flexWrap: 'wrap',
        }}
      >
        <Link
          href={`/u/${encodeURIComponent(owner?.username || owner?.id || '')}`}
          style={{ textDecoration: 'none', color: 'inherit' }}
        >
          <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Dikelola oleh Host:</div>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--primary)' }}>
            {ownerName} {owner?.is_verified_host && '✓'}
          </div>
        </Link>

        {waUrl ? (
          <a
            href={waUrl}
            target="_blank"
            rel="noopener noreferrer"
            style={{
              background: '#16a34a',
              color: '#ffffff',
              padding: '10px 18px',
              borderRadius: 8,
              textDecoration: 'none',
              fontWeight: 700,
              fontSize: 13.5,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            💬 Booking via WhatsApp
          </a>
        ) : (
          <a
            href="todoin://open"
            style={{
              background: 'var(--primary)',
              color: '#ffffff',
              padding: '10px 18px',
              borderRadius: 8,
              textDecoration: 'none',
              fontWeight: 700,
              fontSize: 13.5,
            }}
          >
            Buka di Aplikasi
          </a>
        )}
      </div>
    </article>
  );
}
