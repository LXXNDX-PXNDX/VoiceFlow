import { motion, useReducedMotion } from "framer-motion";
import {
  ArrowDown,
  ArrowRight,
  Check,
  Github,
  Keyboard,
  Mic,
  ShieldCheck,
} from "lucide-react";

export const DOWNLOAD_URL =
  "https://github.com/LXXNDX-PXNDX/VoiceFlow/releases/latest";
export const SOURCE_URL = "https://github.com/LXXNDX-PXNDX/VoiceFlow";

const ease = [0.22, 1, 0.36, 1] as const;

function Waveform() {
  const reduceMotion = useReducedMotion();
  const bars = [18, 32, 48, 26, 64, 42, 78, 50, 92, 56, 74, 40, 62, 34, 50, 24, 38];

  return (
    <div
      className="relative mx-auto flex h-28 w-full max-w-3xl items-center justify-center gap-1.5 overflow-hidden sm:h-36 sm:gap-2"
      aria-label="Animated audio waveform"
      role="img"
    >
      <div className="absolute inset-x-0 top-1/2 h-px bg-ink/10" />
      {bars.map((height, index) => (
        <motion.span
          key={`${height}-${index}`}
          className="relative block w-1.5 rounded-full bg-ink sm:w-2"
          style={{ height: `${height}%` }}
          animate={
            reduceMotion
              ? undefined
              : {
                  scaleY: [0.42, 1, 0.55, 0.86, 0.42],
                  opacity: [0.32, 0.92, 0.52, 0.76, 0.32],
                }
          }
          transition={{
            duration: 2.4 + (index % 4) * 0.22,
            repeat: Infinity,
            ease: "easeInOut",
            delay: index * 0.045,
          }}
        />
      ))}
    </div>
  );
}

function DownloadButton({ compact = false }: { compact?: boolean }) {
  return (
    <a
      href={DOWNLOAD_URL}
      className={
        compact
          ? "focus-ring inline-flex items-center gap-2 rounded-full bg-ink px-5 py-2.5 text-sm font-semibold text-paper transition-transform hover:-translate-y-0.5"
          : "focus-ring group inline-flex min-h-14 items-center justify-center gap-3 rounded-full bg-ink px-7 py-4 text-base font-semibold text-paper shadow-[0_12px_40px_rgba(23,23,20,0.18)] transition-all hover:-translate-y-0.5 hover:shadow-[0_16px_50px_rgba(23,23,20,0.24)] sm:px-8"
      }
      aria-label="Download VoiceFlow for macOS"
    >
      <ArrowDown className={compact ? "h-4 w-4" : "h-5 w-5"} aria-hidden="true" />
      Download for macOS
    </a>
  );
}

function App() {
  const reduceMotion = useReducedMotion();
  const reveal = {
    initial: { opacity: 0, y: reduceMotion ? 0 : 22 },
    whileInView: { opacity: 1, y: 0 },
    viewport: { once: true, amount: 0.2 },
    transition: { duration: 0.7, ease },
  };

  return (
    <div className="min-h-screen overflow-x-hidden bg-paper text-ink selection:bg-accent selection:text-white">
      <header className="mx-auto flex w-full max-w-7xl items-center justify-between px-5 py-5 sm:px-8 lg:px-12">
        <a href="#top" className="focus-ring inline-flex items-center gap-2.5 rounded-full" aria-label="VoiceFlow home">
          <span className="grid h-8 w-8 place-items-center rounded-[10px] bg-ink text-paper" aria-hidden="true">
            <span className="flex items-center gap-[2px]">
              {[8, 14, 20, 12, 7].map((height, index) => (
                <span key={index} className="w-[2px] rounded-full bg-current" style={{ height }} />
              ))}
            </span>
          </span>
          <span className="text-[15px] font-bold tracking-[-0.02em]">VoiceFlow</span>
        </a>

        <nav className="flex items-center gap-2 sm:gap-3" aria-label="Primary navigation">
          <a
            href={SOURCE_URL}
            target="_blank"
            rel="noreferrer"
            className="focus-ring inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-ink/[0.65] transition-colors hover:text-ink sm:px-4"
          >
            <Github className="h-4 w-4" aria-hidden="true" />
            <span className="hidden sm:inline">Open source</span>
          </a>
          <div className="hidden sm:block">
            <DownloadButton compact />
          </div>
        </nav>
      </header>

      <main id="top">
        <section className="mx-auto flex min-h-[calc(100svh-78px)] w-full max-w-7xl flex-col justify-center px-5 pb-14 pt-16 sm:px-8 sm:pb-20 sm:pt-24 lg:px-12 lg:pt-28">
          <motion.div
            initial={{ opacity: 0, y: reduceMotion ? 0 : 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.65, ease }}
            className="mx-auto max-w-5xl text-center"
          >
            <div className="mb-7 inline-flex items-center gap-2 rounded-full border border-ink/10 bg-white/60 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.14em] text-ink/60">
              <span className="h-1.5 w-1.5 rounded-full bg-accent" />
              Free and open source for macOS
            </div>

            <h1 className="text-balance text-[clamp(3.7rem,10vw,8.8rem)] font-semibold leading-[0.82] tracking-[-0.075em]">
              Speak.
              <br />
              <span className="text-ink/[0.38]">It types.</span>
            </h1>

            <p className="mx-auto mt-8 max-w-2xl text-balance text-lg leading-relaxed text-ink/[0.62] sm:mt-10 sm:text-xl">
              VoiceFlow turns natural speech into clean text, so you can talk to AI, write messages, draft emails, and finish longer thoughts without touching the keyboard.
            </p>

            <div className="mt-9 flex flex-col items-center justify-center gap-4 sm:flex-row">
              <DownloadButton />
              <a
                href={SOURCE_URL}
                target="_blank"
                rel="noreferrer"
                className="focus-ring group inline-flex min-h-14 items-center justify-center gap-2 rounded-full px-6 py-4 text-base font-semibold text-ink/70 transition-colors hover:text-ink"
              >
                <Github className="h-5 w-5" aria-hidden="true" />
                View source
                <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" aria-hidden="true" />
              </a>
            </div>

            <p className="mt-5 text-sm text-ink/[0.45]">macOS 14 or newer · Apple Silicon · No account required</p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.25, duration: 0.8 }}
            className="mt-10 sm:mt-14"
          >
            <Waveform />
          </motion.div>
        </section>

        <section className="border-y border-ink/10 bg-white/[0.45]">
          <div className="mx-auto grid w-full max-w-7xl grid-cols-2 gap-px px-5 py-6 sm:grid-cols-4 sm:px-8 lg:px-12">
            {["AI chats", "Messages", "Emails", "Long-form writing"].map((item) => (
              <div key={item} className="flex items-center justify-center gap-2 py-3 text-center text-sm font-semibold text-ink/[0.58] sm:text-base">
                <Check className="h-4 w-4 text-accent" aria-hidden="true" />
                {item}
              </div>
            ))}
          </div>
        </section>

        <section className="mx-auto w-full max-w-7xl px-5 py-24 sm:px-8 sm:py-32 lg:px-12 lg:py-40">
          <motion.div {...reveal} className="grid gap-14 lg:grid-cols-[0.85fr_1.15fr] lg:gap-24">
            <div>
              <p className="section-label">How it works</p>
              <h2 className="mt-5 max-w-xl text-balance text-4xl font-semibold leading-[0.98] tracking-[-0.055em] sm:text-6xl">
                Your voice, straight into text.
              </h2>
            </div>

            <ol className="divide-y divide-ink/[0.12] border-y border-ink/[0.12]">
              {[
                {
                  number: "01",
                  icon: Mic,
                  title: "Start speaking",
                  text: "Open VoiceFlow and talk naturally. No special commands or robotic pacing.",
                },
                {
                  number: "02",
                  icon: Keyboard,
                  title: "VoiceFlow transcribes",
                  text: "Local whisper.cpp speech recognition turns your words into text without depending on a cloud transcription service.",
                },
                {
                  number: "03",
                  icon: ArrowRight,
                  title: "Keep moving",
                  text: "VoiceFlow places the finished transcript exactly where you need it, ready to send or keep editing.",
                },
              ].map(({ number, icon: Icon, title, text }) => (
                <li key={number} className="grid gap-4 py-7 sm:grid-cols-[54px_1fr] sm:gap-6 sm:py-9">
                  <div className="flex items-center justify-between sm:block">
                    <span className="text-xs font-bold tracking-[0.15em] text-ink/[0.32]">{number}</span>
                    <Icon className="h-5 w-5 text-accent sm:mt-8" aria-hidden="true" />
                  </div>
                  <div>
                    <h3 className="text-2xl font-semibold tracking-[-0.035em]">{title}</h3>
                    <p className="mt-2 max-w-xl text-base leading-relaxed text-ink/[0.57] sm:text-lg">{text}</p>
                  </div>
                </li>
              ))}
            </ol>
          </motion.div>
        </section>

        <section className="mx-auto w-full max-w-7xl px-5 pb-24 sm:px-8 sm:pb-32 lg:px-12 lg:pb-40">
          <motion.div {...reveal} className="grid overflow-hidden rounded-[2rem] bg-ink text-paper lg:grid-cols-2">
            <div className="flex min-h-[420px] flex-col justify-between p-7 sm:p-12 lg:min-h-[560px] lg:p-16">
              <div>
                <p className="section-label text-paper/[0.45]">Built differently</p>
                <h2 className="mt-5 max-w-xl text-balance text-4xl font-semibold leading-[0.98] tracking-[-0.055em] sm:text-6xl">
                  Simple enough to disappear.
                </h2>
              </div>
              <p className="max-w-lg text-lg leading-relaxed text-paper/[0.58]">
                VoiceFlow stays close at hand, asks for no account, and keeps transcription local on your Mac so your voice does not need a cloud service.
              </p>
            </div>

            <div className="grid content-center gap-8 border-t border-paper/10 p-7 sm:p-12 lg:border-l lg:border-t-0 lg:p-16">
              {[
                {
                  icon: ShieldCheck,
                  title: "Open by default",
                  text: "The complete source code is public on GitHub under the MIT License—not hidden behind a subscription.",
                },
                {
                  icon: Mic,
                  title: "Native macOS foundations",
                  text: "Built as a native SwiftUI app with local whisper.cpp transcription for a focused desktop experience.",
                },
                {
                  icon: Keyboard,
                  title: "Made for real writing",
                  text: "Useful wherever typing slows down your thinking: AI prompts, replies, emails, and drafts.",
                },
              ].map(({ icon: Icon, title, text }) => (
                <div key={title} className="grid grid-cols-[32px_1fr] gap-4">
                  <Icon className="mt-0.5 h-5 w-5 text-accent-light" aria-hidden="true" />
                  <div>
                    <h3 className="text-lg font-semibold tracking-[-0.02em]">{title}</h3>
                    <p className="mt-1.5 leading-relaxed text-paper/50">{text}</p>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        </section>

        <section id="download" className="border-t border-ink/10">
          <motion.div {...reveal} className="mx-auto flex w-full max-w-7xl flex-col items-start justify-between gap-10 px-5 py-24 sm:px-8 sm:py-32 lg:flex-row lg:items-end lg:px-12 lg:py-40">
            <div className="max-w-3xl">
              <p className="section-label">Free forever</p>
              <h2 className="mt-5 text-balance text-5xl font-semibold leading-[0.9] tracking-[-0.065em] sm:text-7xl lg:text-8xl">
                Give your keyboard a break.
              </h2>
              <p className="mt-7 max-w-xl text-lg leading-relaxed text-ink/[0.58]">
                Open the latest GitHub release and download the current macOS build. Everything behind it is public and inspectable.
              </p>
            </div>
            <div className="flex w-full flex-col items-start gap-4 lg:w-auto lg:items-end">
              <DownloadButton />
              <a
                href={SOURCE_URL}
                target="_blank"
                rel="noreferrer"
                className="focus-ring inline-flex items-center gap-2 rounded-full text-sm font-semibold text-ink/[0.52] transition-colors hover:text-ink"
              >
                <Github className="h-4 w-4" aria-hidden="true" />
                Inspect the source on GitHub
              </a>
            </div>
          </motion.div>
        </section>
      </main>

      <footer className="border-t border-ink/10">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-3 px-5 py-7 text-sm text-ink/[0.45] sm:flex-row sm:items-center sm:justify-between sm:px-8 lg:px-12">
          <p>© {new Date().getFullYear()} VoiceFlow. Free and open source.</p>
          <a href={SOURCE_URL} target="_blank" rel="noreferrer" className="focus-ring rounded-full transition-colors hover:text-ink">
            GitHub · LXXNDX-PXNDX/VoiceFlow
          </a>
        </div>
      </footer>
    </div>
  );
}

export default App;
