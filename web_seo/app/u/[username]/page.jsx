import Link from 'next/link';
import { notFound } from 'next/navigation';
import {
  fetchUserByUsernameOrId,
  fetchUserPostsAndListings,
  getUserAvatarUrl,
} from '../../../lib/pb';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }) {
  const user = await fetchUserByUsernameOrId(params.username);
  if (!user) {
    return { title: 'Profil Tidak Ditemukan' };
  }

  const displayName = user.name || `@${user.username}`;
  const description =
    user.bio || `Lihat cerita perjalanan dan Travel History ${displayName} di todoin.id.`;
  const avatar = user.avatar ? getUserAvatarUrl(user, user.avatar) : undefined;

  return {
    title: `${displayName} (@${user.username})`,
    description,
    alternates: {
      canonical: `/u/${encodeURIComponent(user.username || user.id)}`,
    },
    openGraph: {
      title: `${displayName} — todoin.id`,
      description,
      type: 'profile',
      images: avatar ? [{ url: avatar }] : [],
    },
  };
}

export default async function UserProfilePage({ params }) {
  const user = await fetchUserByUsernameOrId(params.username);
  if (!user) {
    notFound();
  }

  const { posts, listings } = await fetchUserPostsAndListings(user.id);
  const displayName = user.name || `@${user.username}`;
  const avatar = user.avatar ? getUserAvatarUrl(user, user.avatar) : '';

  const visitedCities = Array.from(
    new Set(
      posts
        .filter((p) => p.is_live_gps && p.city)
        .map((p) => `${p.city}${p.province ? `, ${p.province}` : ''}`)
    )
  );

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <section
        style={{
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          borderRadius: 14,
          padding: 20,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          {avatar ? (
            <img
              src={avatar}
              alt={displayName}
              style={{
                width: 68,
                height: 68,
                borderRadius: '50%',
                objectFit: 'cover',
              }}
            />
          ) : (
            <div
              style={{
                width: 68,
                height: 68,
                borderRadius: '50%',
                background: 'rgba(15, 118, 110, 0.14)',
                color: 'var(--primary)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 26,
                fontWeight: 800,
              }}
            >
              {displayName[0]?.toUpperCase() || 'T'}
            </div>
          )}

          <div>
            <h1 style={{ fontSize: 22, fontWeight: 800 }}>
              {displayName}{' '}
              {user.is_verified_host && (
                <span
                  style={{
                    fontSize: 12,
                    background: 'var(--gps-bg)',
                    color: 'var(--gps-fg)',
                    padding: '2px 8px',
                    borderRadius: 999,
                    verticalAlign: 'middle',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 3,
                  }}
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                  </svg>
                  Verified Local Host
                </span>
              )}
            </h1>
            <div style={{ color: 'var(--text-muted)', fontSize: 13.5 }}>
              @{user.username} • {posts.length} Cerita • {visitedCities.length} Kota Terverifikasi GPS
            </div>
          </div>
        </div>

        {user.bio && (
          <p style={{ marginTop: 14, fontSize: 14.5, color: 'var(--text-secondary)' }}>
            {user.bio}
          </p>
        )}

        {visitedCities.length > 0 && (
          <div style={{ marginTop: 14, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {visitedCities.map((city, i) => (
              <span
                key={i}
                style={{
                  background: '#f1f5f9',
                  border: '1px solid var(--border)',
                  padding: '3px 10px',
                  borderRadius: 999,
                  fontSize: 12,
                  color: 'var(--text-secondary)',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 3,
                }}
              >
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" />
                  <circle cx="12" cy="10" r="3" />
                </svg>
                {city}
              </span>
            ))}
          </div>
        )}
      </section>

      {user.is_verified_host && listings.length > 0 && (
        <section>
          <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>
            Layanan Lokal ({listings.length})
          </h2>
          <div style={{ display: 'grid', gap: 10 }}>
            {listings.map((item) => (
              <div
                key={item.id}
                style={{
                  background: 'var(--surface)',
                  border: '1px solid var(--border)',
                  borderRadius: 12,
                  padding: 14,
                }}
              >
                <div style={{ fontWeight: 700, fontSize: 15.5 }}>{item.title}</div>
                <div style={{ color: 'var(--text-muted)', fontSize: 12.5 }}>
                  {item.city}, {item.province} • Rp{' '}
                  {Number(item.price || 0).toLocaleString('id-ID')} / {item.price_unit}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>
          Cerita Perjalanan ({posts.length})
        </h2>
        <div style={{ display: 'grid', gap: 12 }}>
          {posts.map((post) => (
            <Link
              key={post.id}
              href={`/p/${encodeURIComponent(post.slug || post.id)}`}
              style={{
                display: 'block',
                background: 'var(--surface)',
                border: '1px solid var(--border)',
                borderRadius: 12,
                padding: 14,
                textDecoration: 'none',
                color: 'inherit',
              }}
            >
              <div style={{ fontWeight: 700, fontSize: 16 }}>{post.title}</div>
              <div style={{ fontSize: 12.5, color: 'var(--text-muted)', marginTop: 2 }}>
                {post.category} • {[post.place_name, post.city].filter(Boolean).join(', ')}
              </div>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}
