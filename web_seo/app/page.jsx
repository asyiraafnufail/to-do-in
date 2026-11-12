import Link from 'next/link';
import { fetchRecentPosts, getPostImageUrl } from '../lib/pb';

export const dynamic = 'force-dynamic';

export default async function HomePage() {
  const posts = await fetchRecentPosts(20);

  return (
    <div>
      <section style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 800, marginBottom: 6 }}>
          Cerita Perjalanan &amp; To-Do Wisata Indonesia
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: 14.5 }}>
          Inspirasi destinasi terverifikasi Live GPS, checklist aktivitas nyata, dan layanan lokal tepercaya.
        </p>
      </section>

      {posts.length === 0 ? (
        <div
          style={{
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 12,
            padding: 32,
            textAlign: 'center',
            color: 'var(--text-muted)',
          }}
        >
          Belum ada cerita perjalanan yang dipublikasikan atau server PocketBase sedang offline.
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 14 }}>
          {posts.map((post) => {
            const slug = post.slug || post.id;
            const author = post.expand?.author;
            const authorName =
              author?.name ||
              (author?.username ? `@${author.username}` : 'Traveler');
            const loc = [post.place_name, post.city, post.province]
              .filter(Boolean)
              .join(', ');
            const thumb =
              Array.isArray(post.images) && post.images.length > 0
                ? getPostImageUrl(post, post.images[0])
                : '';

            return (
              <Link
                key={post.id}
                href={`/p/${encodeURIComponent(slug)}`}
                style={{
                  display: 'block',
                  background: 'var(--surface)',
                  border: '1px solid var(--border)',
                  borderRadius: 12,
                  padding: 16,
                  textDecoration: 'none',
                  color: 'inherit',
                }}
              >
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 8 }}>
                  <span
                    style={{
                      background: 'rgba(15, 118, 110, 0.1)',
                      color: 'var(--primary)',
                      padding: '3px 10px',
                      borderRadius: 999,
                      fontSize: 11.5,
                      fontWeight: 700,
                    }}
                  >
                    {post.category || 'Wisata'}
                  </span>
                  {post.is_live_gps && (
                    <span
                      style={{
                        background: 'var(--gps-bg)',
                        color: 'var(--gps-fg)',
                        padding: '3px 10px',
                        borderRadius: 999,
                        fontSize: 11.5,
                        fontWeight: 700,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 4,
                      }}
                    >
                      <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" />
                        <circle cx="12" cy="10" r="3" />
                      </svg>
                      Live GPS
                    </span>
                  )}
                </div>

                {thumb && (
                  <img
                    src={thumb}
                    alt={post.title}
                    style={{
                      width: '100%',
                      maxHeight: 240,
                      objectFit: 'cover',
                      borderRadius: 10,
                      marginBottom: 10,
                    }}
                  />
                )}

                <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>
                  {post.title}
                </h2>
                <div style={{ fontSize: 12.5, color: 'var(--text-muted)', marginBottom: 8 }}>
                  Oleh <strong>{authorName}</strong>
                  {loc ? ` • ${loc}` : ''}
                </div>
                <p style={{ fontSize: 14, color: 'var(--text-secondary)' }}>
                  {(post.content || '').slice(0, 160)}
                  {(post.content || '').length > 160 ? '...' : ''}
                </p>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
