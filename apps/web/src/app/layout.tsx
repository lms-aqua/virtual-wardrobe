import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Virtual Wardrobe",
  description:
    "A private, consent-first virtual try-on wardrobe. Your body scans never leave your control.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // iPhone-first: allow zoom for accessibility, but a sensible max.
  maximumScale: 5,
  themeColor: "#0b0b12",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-dvh bg-white text-brand-fg antialiased dark:bg-brand-fg dark:text-white">
        {children}
      </body>
    </html>
  );
}
