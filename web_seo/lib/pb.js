export function getPbUrl() {
  const url =
    process.env.PB_URL ||
    process.env.NEXT_PUBLIC_PB_URL ||
    'http://127.0.0.1:8090';
  return url.replace(/\/+$/, '');
}

export function getPostImageUrl(post, filename) {
  if (!filename) return '';
  const pbUrl = getPbUrl();
  const collectionId = post.collectionId || 'pbc_posts_00001';
  return `${pbUrl}/api/files/${collectionId}/${post.id}/${encodeURIComponent(filename)}`;
}

export function getUserAvatarUrl(user, filename) {
  if (!filename) return '';
  const pbUrl = getPbUrl();
  const collectionId = user.collectionId || '_pb_users_auth_';
  return `${pbUrl}/api/files/${collectionId}/${user.id}/${encodeURIComponent(filename)}`;
}

export async function fetchRecentPosts(limit = 20) {
  try {
    const pbUrl = getPbUrl();
    const res = await fetch(
      `${pbUrl}/api/collections/posts/records?perPage=${limit}&sort=-created&expand=author`,
      { next: { revalidate: 60 } }
    );
    if (!res.ok) return [];
    const data = await res.json();
    return data.items || [];
  } catch (_) {
    return [];
  }
}

export async function fetchPostBySlugOrId(slugOrId) {
  if (!slugOrId) return null;
  const clean = String(slugOrId).replace(/[^a-zA-Z0-9_-]/g, '');
  if (!clean) return null;

  try {
    const pbUrl = getPbUrl();
    const filter = encodeURIComponent(`slug="${clean}" || id="${clean}"`);
    const res = await fetch(
      `${pbUrl}/api/collections/posts/records?filter=(${filter})&perPage=1&expand=author`,
      { next: { revalidate: 60 } }
    );
    if (!res.ok) return null;
    const data = await res.json();
    return (data.items || [])[0] || null;
  } catch (_) {
    return null;
  }
}

export async function fetchUserByUsernameOrId(usernameOrId) {
  if (!usernameOrId) return null;
  const clean = String(usernameOrId).replace(/[^a-zA-Z0-9._-]/g, '');
  if (!clean) return null;

  try {
    const pbUrl = getPbUrl();
    const filter = encodeURIComponent(`username="${clean}" || id="${clean}"`);
    const res = await fetch(
      `${pbUrl}/api/collections/users/records?filter=(${filter})&perPage=1`,
      { next: { revalidate: 60 } }
    );
    if (!res.ok) return null;
    const data = await res.json();
    return (data.items || [])[0] || null;
  } catch (_) {
    return null;
  }
}

export async function fetchUserPostsAndListings(userId) {
  if (!userId) return { posts: [], listings: [] };
  const pbUrl = getPbUrl();
  try {
    const [postsRes, listingsRes] = await Promise.all([
      fetch(
        `${pbUrl}/api/collections/posts/records?filter=author="${userId}"&sort=-created&perPage=20`,
        { next: { revalidate: 60 } }
      ),
      fetch(
        `${pbUrl}/api/collections/listings/records?filter=owner="${userId}"&sort=-created&perPage=20`,
        { next: { revalidate: 60 } }
      ),
    ]);

    const posts = postsRes.ok ? (await postsRes.json()).items || [] : [];
    const listings = listingsRes.ok
      ? (await listingsRes.json()).items || []
      : [];
    return { posts, listings };
  } catch (_) {
    return { posts: [], listings: [] };
  }
}
