import Link from 'next/link';
import { notFound } from 'next/navigation';
import { fetchPostBySlugOrId, getPostImageUrl } from '../../../lib/pb';

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }) {
  const post = await fetchPostBySlugOrId(params.slug);
  if (!post) {
    return { title: 'Cerita Tidak Ditemukan' };
  }

  const loc = [post.place_name, post.city, post.province].filter(Boolean).join(', ');
  const description =
    (post.content || '').replace(/\s+/g, ' ').trim().slice(0, 160) ||
    `Cerita perjalanan dan rekomendasi To-Do di ${loc || 'Indonesia'}.`;
  const ogImage =
    Array.isArray(post.images) && post.images.length > 0
      ? getPostImageUrl(post, post.images[0])
      : undefined;

  return {
    title: post.title,
    description,
    alternates: {
      canonical: `/p/${encodeURIComponent(post.slug || post.id)}`,
    },
    openGraph: {
      title: `${post.title} — todoin.id`,
      description,
      type: 'article',
      url: `/p/${encodeURIComponent(post.slug || post.id)}`,
      images: ogImage ? [{ url: ogImage }] : [],
    },
    twitter: {
      card: ogImage ? 'summary_large_image' : 'summary',
      title: `${post.title} — todoin.id`,
      description,
      images: ogImage ? [ogImage] : [],
    },
  };
}

export default async function PostPage({ params }) {
  const post = await fetchPostBySlugOrId(params.slug);
  if (!post) {
    notFound();
  }

  const author = post.expand?.author;
  const authorName =
    author?.name || (author?.username ? `@${author.username}` : 'Traveler');
  const authorUsername = author?.username || author?.id;
  const loc = [post.place_name, post.city, post.province].filter(Boolean).join(', ');
  const images = Array.isArray(post.images) ? post.images : [];
  const todos = Array.isArray(post.todo_items) ? post.todo_items : [];

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,
    description: (post.content || '').slice(0, 160),
    author: {
      '@type': 'Person',
      name: authorName,
    },
    contentLocation: {
      '@type': 'Place',
      name: loc || 'Indonesia',
    },
    image: images.map((f) => getPostImageUrl(post, f)),
    datePublished: post.created,
    dateModified: post.updated || post.created,
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
          {post.category || 'Wisata'}
        </span>
        {post.is_live_gps && (
          <span
            style={{
              background: 'var(--gps-bg)',
              color: 'var(--gps-fg)',
              padding: '4px 12px',
              borderRadius: 999,
              fontSize: 12,
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" />
              <circle cx="12" cy="10" r="3" />
            </svg>
            Live GPS
          </span>
        )}
      </div>

      <h1 style={{ fontSize: 25, fontWeight: 800, lineHeight: 1.3, marginBottom: 8 }}>
        {post.title}
      </h1>

      <div style={{ fontSize: 13.5, color: 'var(--text-muted)', marginBottom: 18 }}>
        Ditulis oleh{' '}
        {authorUsername ? (
          <Link
            href={`/u/${encodeURIComponent(authorUsername)}`}
            style={{ color: 'var(--primary)', fontWeight: 700, textDecoration: 'none' }}
          >
            {authorName}
          </Link>
        ) : (
          <strong>{authorName}</strong>
        )}
        {author?.is_verified_host ? (
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, marginLeft: 6, color: 'var(--primary)', fontWeight: 600 }}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
            </svg>
            Local Host
          </span>
        ) : ''}
        {loc ? ` • ${loc}` : ''}
      </div>

      {images.length > 0 && (
        <div style={{ display: 'grid', gap: 10, marginBottom: 20 }}>
          {images.map((file, idx) => (
            <img
              key={idx}
              src={getPostImageUrl(post, file)}
              alt={`${post.title} - foto ${idx + 1}`}
              style={{
                width: '100%',
                maxHeight: 440,
                objectFit: 'cover',
                borderRadius: 10,
              }}
            />
          ))}
        </div>
      )}

      <div
        style={{
          fontSize: 15.5,
          lineHeight: 1.7,
          color: 'var(--text-primary)',
          whiteSpace: 'pre-line',
        }}
      >
        {post.content}
      </div>

      {todos.length > 0 && (
        <section
          style={{
            marginTop: 24,
            background: '#f1f5f9',
            border: '1px solid var(--border)',
            borderRadius: 12,
            padding: 16,
          }}
        >
          <h2
            style={{
              fontSize: 15.5,
              fontWeight: 700,
              color: 'var(--accent)',
              marginBottom: 10,
            }}
          >
            To-Do Rekomendasi Penulis ({todos.length})
          </h2>
          <ul style={{ paddingLeft: 18, display: 'grid', gap: 6 }}>
            {todos.map((item, idx) => (
              <li key={idx} style={{ fontSize: 14, color: 'var(--text-primary)' }}>
                {String(item)}
              </li>
            ))}
          </ul>
        </section>
      )}

      <div style={{ marginTop: 24, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
        <a href={`todoin://post/${post.id}`} className="btn-open-app">
          Simpan Checklist di Aplikasi todoin.id
        </a>
        <Link
          href="/"
          style={{
            padding: '8px 16px',
            borderRadius: 8,
            border: '1px solid var(--border)',
            color: 'var(--text-secondary)',
            textDecoration: 'none',
            fontSize: 13,
            fontWeight: 600,
          }}
        >
          Jelajahi Cerita Lain
        </Link>
      </div>
    </article>
  );
}
