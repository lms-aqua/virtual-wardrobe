/**
 * Minimal typed API client. In Phase 3 this is replaced/extended by a client
 * generated from the backend OpenAPI spec (single source of truth) plus Zod
 * response validation at the boundary. Credentials are included so the secure,
 * httpOnly session cookie flows automatically.
 */

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export type LiveHealth = { status: string; version: string };

export async function getLiveHealth(): Promise<LiveHealth> {
  const res = await fetch(`${API_BASE_URL}/health/live`, {
    credentials: "include",
    cache: "no-store",
  });
  if (!res.ok) {
    throw new Error(`Health check failed: ${res.status}`);
  }
  return (await res.json()) as LiveHealth;
}
