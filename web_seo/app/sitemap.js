import { fetchRecentPosts, fetchRecentListings } from '../lib/pb';

export const dynamic = 'force-dynamic';

export default async function sitemap() {
  const siteUrl = (process.env.NEXT_PUBLIC_SITE_URL || 'https://todoin.id').replace(
    /\/+$/,
    ''
  );
  const [posts, listings] = await Promise.all([
    fetchRecentPosts(100),
    fetchRecentListings(50),
  ]);

  const postEntries = posts.map((post) => ({
    url: `${siteUrl}/p/${encodeURIComponent(post.slug || post.id)}`,
    lastModified: post.updated || post.created || new Date().toISOString(),
    changeFrequency: 'weekly',
    priority: 0.8,
  }));

  const listingEntries = listings.map((l) => ({
    url: `${siteUrl}/listing/${encodeURIComponent(l.id)}`,
    lastModified: l.updated || l.created || new Date().toISOString(),
    changeFrequency: 'weekly',
    priority: 0.8,
  }));

  return [
    {
      url: siteUrl,
      lastModified: new Date().toISOString(),
      changeFrequency: 'daily',
      priority: 1,
    },
    ...postEntries,
    ...listingEntries,
  ];
}
