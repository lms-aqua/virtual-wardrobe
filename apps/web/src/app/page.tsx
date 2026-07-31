import Link from "next/link";

const privacyPoints = [
  "You must be an adult and give explicit consent before any scan.",
  "Scans upload to private storage — never a public URL.",
  "Raw scan photos are deleted after your avatar is built, unless you keep them.",
  "No face recognition. You can crop, blur, or omit your face.",
  "One tap deletes your scans, avatar, measurements, and account — permanently.",
];

export default function LandingPage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-3xl flex-col justify-center gap-10 px-6 py-16">
      <header className="space-y-4">
        <p className="text-sm font-medium uppercase tracking-widest text-brand">
          Virtual Wardrobe
        </p>
        <h1 className="text-4xl font-bold sm:text-5xl">
          Your body. Your avatar. Your privacy.
        </h1>
        <p className="text-lg opacity-80">
          Build a personalized 3D avatar from a guided body scan, then try on
          digital clothing on your iPhone, iPad, or computer — with strong,
          consent-first privacy at every step.
        </p>
      </header>

      <section aria-labelledby="privacy-heading" className="space-y-3">
        <h2 id="privacy-heading" className="text-xl font-semibold">
          Privacy you can verify
        </h2>
        <ul className="space-y-2">
          {privacyPoints.map((point) => (
            <li key={point} className="flex gap-2">
              <span aria-hidden className="text-brand">
                ✓
              </span>
              <span className="opacity-90">{point}</span>
            </li>
          ))}
        </ul>
      </section>

      <nav className="flex flex-wrap gap-4" aria-label="Get started">
        <Link
          href="/login"
          className="rounded-lg bg-brand px-5 py-3 font-medium text-white focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          Sign in
        </Link>
        <Link
          href="/dashboard"
          className="rounded-lg border border-current px-5 py-3 font-medium focus:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          Open my avatar
        </Link>
      </nav>

      <footer className="mt-auto pt-8 text-sm opacity-60">
        MVP build — avatar generation runs on a clearly-labeled mock provider.
        No claims of tailoring- or medical-grade accuracy.
      </footer>
    </main>
  );
}
