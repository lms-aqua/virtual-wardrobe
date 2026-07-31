/**
 * Browser API client. Uses a bearer token stored in localStorage (the API also
 * sets an httpOnly cookie, but bearer keeps cross-origin dev simple).
 */

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://wardrobe-api.losthosting.com";

const TOKEN_KEY = "vw.token";

export const auth = {
  get token(): string | null {
    return typeof window === "undefined" ? null : localStorage.getItem(TOKEN_KEY);
  },
  set(token: string) {
    localStorage.setItem(TOKEN_KEY, token);
  },
  clear() {
    localStorage.removeItem(TOKEN_KEY);
  },
};

async function req<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (auth.token) headers.Authorization = `Bearer ${auth.token}`;
  const res = await fetch(`${API_BASE_URL}/${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
  return (res.status === 204 ? undefined : await res.json()) as T;
}

export interface Measurement {
  height_cm?: number | null;
  chest_cm?: number | null;
  waist_cm?: number | null;
  hip_cm?: number | null;
}
export interface Avatar {
  id: string;
  status: string;
  confidence: number | null;
  mesh_url: string | null;
  thumb_url: string | null;
  is_mock: boolean;
  measurements: Measurement | null;
}
export interface Garment {
  id: string;
  brand: string;
  name: string;
  category: string;
  price_cents: number | null;
  product_url: string | null;
}

export const api = {
  requestMagicLink: (email: string, is_adult: boolean) =>
    req<{ sent: boolean; dev_token: string | null }>("POST", "auth/magic-link", { email, is_adult }),
  verify: (token: string) =>
    req<{ access_token: string; user_id: string }>("POST", "auth/magic-link/verify", { token }),
  me: () => req<{ id: string; email: string }>("GET", "me"),
  avatars: () => req<Avatar[]>("GET", "avatars"),
  garments: () => req<Garment[]>("GET", "garments"),
};
