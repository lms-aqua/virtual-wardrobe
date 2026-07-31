"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api, auth, type Avatar, type Garment } from "@/lib/api";
import AvatarViewer from "@/components/AvatarViewer";

export default function DashboardPage() {
  const [avatar, setAvatar] = useState<Avatar | null>(null);
  const [garments, setGarments] = useState<Garment[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    if (!auth.token) {
      router.push("/login");
      return;
    }
    Promise.all([api.avatars(), api.garments()])
      .then(([a, g]) => {
        setAvatar(a[0] ?? null);
        setGarments(g);
        setLoading(false);
      })
      .catch(() => {
        auth.clear();
        router.push("/login");
      });
  }, [router]);

  if (loading) return <main className="grid min-h-dvh place-items-center">Loading…</main>;

  return (
    <main className="mx-auto max-w-4xl px-6 py-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Your avatar</h1>
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

      {avatar?.mesh_url ? (
        <>
          <AvatarViewer url={avatar.mesh_url} />
          <p className="mt-3 text-sm opacity-60">
            Drag to rotate · scroll to zoom · measurement-based 3D preview
            {avatar.is_mock ? " (stylized, not a photo reconstruction)" : ""}.
          </p>
          {avatar.measurements && (
            <div className="mt-4 flex gap-6 text-sm">
              <Stat label="Height" v={avatar.measurements.height_cm} />
              <Stat label="Chest" v={avatar.measurements.chest_cm} />
              <Stat label="Waist" v={avatar.measurements.waist_cm} />
              <Stat label="Hip" v={avatar.measurements.hip_cm} />
            </div>
          )}
        </>
      ) : (
        <div className="rounded-2xl border border-white/10 p-8 text-center opacity-70">
          No avatar yet — run a body scan in the iOS app, then refresh here.
        </div>
      )}

      <h2 className="mb-3 mt-10 text-lg font-semibold">Wardrobe</h2>
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
    </main>
  );
}

function Stat({ label, v }: { label: string; v?: number | null }) {
  return (
    <div>
      <div className="font-semibold">{v != null ? Math.round(v) : "—"}</div>
      <div className="opacity-60">{label}</div>
    </div>
  );
}
