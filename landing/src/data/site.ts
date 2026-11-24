export const site = {
  name: "Wave",
  repoOwner: "get-wave",
  repoName: "wave",
  siteUrl: "https://wave.mxv.sh",
  ogImage: "/opengraph.png",
  title: "Wave - The right option for your every word",
  description:
    "A native macOS dictation app that turns your voice into text instantly. Local Whisper for complete privacy, or Groq for ultra-fast transcription.",
  githubUrl: "https://github.com/get-wave/wave",
  downloadUrl: "#download",
  releaseUrl: "#download",
  navLinks: [
    { href: "#features", label: "Features" },
    { href: "#how-it-works", label: "How it works" },
  ],
  ctaPrimary: {
    href: "#download",
    label: "Download for macOS",
  },
  ctaSecondary: {
    href: "https://github.com/get-wave/wave",
    label: "View on GitHub",
  },
} as const;
