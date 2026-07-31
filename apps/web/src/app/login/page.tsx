"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError, api, auth } from "@/lib/api";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [adult, setAdult] = useState(false);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const router = useRouter();

  async function go() {
    setBusy(true);
    setMsg(null);
    try {
      const r = await api.requestMagicLink(email, adult);
      if (r.dev_token) {
        const v = await api.verify(r.dev_token);
        auth.set(v.access_token);
        router.push("/dashboard");
      } else {
        setMsg("Check your email for a sign-in link.");
      }
    } catch (e) {
      // Never render the raw error: it carried the HTTP status and the backend
      // response body straight into the page.
      setMsg(e instanceof ApiError ? e.userMessage : "Something went wrong. Try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 px-6">
      <h1 className="text-3xl font-bold">Sign in</h1>
      <input
        className="rounded-lg bg-white/10 px-4 py-3 outline-none"
        placeholder="Email"
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />
      <label className="flex items-center gap-2 text-sm opacity-80">
        <input type="checkbox" checked={adult} onChange={(e) => setAdult(e.target.checked)} />I
        confirm I am 18 or older.
      </label>
      <button
        className="rounded-lg bg-brand px-5 py-3 font-medium text-white disabled:opacity-40"
        disabled={busy || !email.includes("@") || !adult}
        onClick={go}
      >
        {busy ? "…" : "Continue with email"}
      </button>
      {msg && <p className="text-sm opacity-70">{msg}</p>}
    </main>
  );
}
