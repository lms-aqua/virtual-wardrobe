"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError, api, auth, type Avatar, type Garment } from "@/lib/api";
import AvatarViewer from "@/components/AvatarViewer";

type State =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "ready"; avatar: Avatar | null; garments: Garment[] };

export default function DashboardPage() {
  const [state, setState] = useState<State>({ kind: "loading" });
  const router = useRouter();

  const load = useCallback(async () => {
    setState({ kind: "loading" });
    try {
      const [avatars, garments] = await Promise.all([api.avatars(), api.garments()]);
      setState({ kind: "ready", avatar: avatars[0] ?? null, garments });
    } catch (e) {
      // Only an actual auth failure signs the user out. A 500 or a dropped
      // connection used to land here too and silently cleared the session.
      if (e instanceof ApiError && e.isAuthFailure) {
        auth.clear();
        router.push("/login");
        return;
      }
      setState({
        kind: "error",
        message: e instanceof ApiError ? e.userMessage : "Something went wrong. Try again.",
      });
    }
  }, [router]);

  useEffect(() => {
    if (!auth.token) {
      router.push("/login");
      return;
    }
    void load();
  }, [router, load]);

  return (
    <main className="mx-auto max-w-4xl px-6 py-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Avatar</h1>
        <button
          className="text-sm opacity-70 hover:opacity-100"
          onClick={() => {
            auth.clear();
            router.push("/login");
          }}
        >
          Sign out
        </button>
      </div>

      {state.kind === "loading" && <DashboardSkeleton />}

      {state.kind === "error" && (
        <div className="rounded-2xl border border-white/10 p-8 text-center">
          <p className="font-medium">Couldn’t Load Your Dashboard</p>
          <p className="mt-1 text-sm opacity-70">{state.message}</p>
          <button
            className="mt-4 rounded-lg bg-brand px-5 py-2.5 text-sm font-medium text-white"
            onClick={() => void load()}
          >
            Try Again
          </button>
        </div>
      )}

      {state.kind === "ready" && (
        <>
          <AvatarSection avatar={state.avatar} />
          <h2 className="mb-3 mt-10 text-lg font-semibold">Wardrobe</h2>
          <WardrobeSection garments={state.garments} />
        </>
      )}
    </main>
  );
}

function AvatarSection({ avatar }: { avatar: Avatar | null }) {
  if (!avatar?.mesh_url) {
    return (
      <div className="rounded-2xl border border-white/10 p-8 text-center opacity-70">
        <p className="font-medium">No Avatar Yet</p>
        <p className="mt-1 text-sm">
          Run a Body Scan in the iOS app to build your avatar, then refresh this page.
        </p>
      </div>
    );
  }

  return (
    <>
      <AvatarViewer url={avatar.mesh_url} />
      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-sm opacity-60">
        <StatusPill status={avatar.status} />
        <span>
          Drag to rotate · scroll to zoom · measurement-based 3D preview
          {avatar.is_mock ? " (stylized, not a photo reconstruction)" : ""}.
        </span>
      </div>
      {avatar.measurements && (
        <>
          <h2 className="mb-3 mt-8 text-lg font-semibold">Measurements</h2>
          <div className="flex flex-wrap gap-6 text-sm">
            <Stat label="Height" cm={avatar.measurements.height_cm} />
            <Stat label="Chest" cm={avatar.measurements.chest_cm} />
            <Stat label="Waist" cm={avatar.measurements.waist_cm} />
            <Stat label="Hip" cm={avatar.measurements.hip_cm} />
          </div>
        </>
      )}
    </>
  );
}

function WardrobeSection({ garments }: { garments: Garment[] }) {
  if (garments.length === 0) {
    return (
      <div className="rounded-2xl border border-white/10 p-8 text-center opacity-70">
        <p className="font-medium">No Garments Yet</p>
        <p className="mt-1 text-sm">Add a garment in the iOS app to start building outfits.</p>
      </div>
    );
  }
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      {garments.map((g) => (
        <div key={g.id} className="rounded-xl border border-white/10 p-3 text-sm">
          <div className="font-medium">{g.name}</div>
          <div className="opacity-60">{g.brand}</div>
          {g.price_cents != null && (
            <div className="mt-1">${(g.price_cents / 100).toFixed(2)}</div>
          )}
        </div>
      ))}
    </div>
  );
}

/** Same vocabulary the iOS app uses: Processing / Ready / Failed. */
function StatusPill({ status }: { status: string }) {
  const s = status.toLowerCase();
  const label = s === "ready" || s === "complete" || s === "completed"
    ? "Ready"
    : s === "failed" || s === "error"
      ? "Failed"
      : "Processing";
  return (
    <span className="rounded-full border border-white/15 px-2 py-0.5 text-xs uppercase tracking-wide">
      {label}
    </span>
  );
}

function Stat({ label, cm }: { label: string; cm?: number | null }) {
  return (
    <div>
      <div className="font-semibold">{cm != null ? `${Math.round(cm)} cm` : "—"}</div>
      <div className="opacity-60">{label}</div>
    </div>
  );
}

/** Preserves the page's shape while loading instead of blanking to a word. */
function DashboardSkeleton() {
  return (
    <div aria-label="Loading your dashboard" aria-busy="true">
      <div className="h-64 animate-pulse rounded-2xl bg-white/5" />
      <div className="mt-4 flex gap-6">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-10 w-16 animate-pulse rounded bg-white/5" />
        ))}
      </div>
      <div className="mb-3 mt-10 h-6 w-28 animate-pulse rounded bg-white/5" />
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-20 animate-pulse rounded-xl bg-white/5" />
        ))}
      </div>
    </div>
  );
}
