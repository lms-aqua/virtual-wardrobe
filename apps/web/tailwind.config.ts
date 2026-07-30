import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Placeholder brand palette; refined in Phase 5 design pass.
        brand: {
          DEFAULT: "#6d5efc",
          fg: "#0b0b12",
        },
      },
    },
  },
  plugins: [],
} satisfies Config;
