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

/**
 * A failed API call. Carries the status so callers can tell an expired session
 * apart from a server fault — previously every failure was treated as an auth
 * failure, which signed people out on a transient 500.
 *
 * `message` is diagnostic and deliberately excludes the response body: backend
 * exception text must never reach the interface. Render `userMessage` instead.
 */
export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }

  /** True when the session is gone and the user has to sign in again. */
  get isAuthFailure(): boolean {
    return this.status === 401 || this.status === 403;
  }

  /** Safe to display. Never contains transport or backend detail. */
  get userMessage(): string {
    if (this.status === 0) return "Can’t reach the server. Check your connection and try again.";
    if (this.isAuthFailure) return "Your session has expired. Sign in again.";
    if (this.status === 404) return "That’s no longer available.";
    if (this.status === 429) return "Too many attempts. Wait a moment and try again.";
    if (this.status >= 500) return "The server is having trouble. Try again shortly.";
    return "Something went wrong. Try again.";
  }
}

async function req<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (auth.token) headers.Authorization = `Bearer ${auth.token}`;

  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}/${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    // Offline, DNS failure, CORS rejection — no status to report.
    throw new ApiError(0, `${method} ${path} → network failure`);
  }

  if (!res.ok) throw new ApiError(res.status, `${method} ${path} → ${res.status}`);
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
