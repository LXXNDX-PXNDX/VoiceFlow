import { motion, useReducedMotion } from 'framer-motion'

const downloadUrl =
  'https://github.com/LXXNDX-PXNDX/VoiceFlow/releases/download/v1.2.4/VoiceFlow.dmg'
const sourceUrl = 'https://github.com/LXXNDX-PXNDX/VoiceFlow'

const useCases = [
  {
    number: '01',
    title: 'Talk to AI',
    text: 'Say the full thought instead of compressing it into a few rushed words.',
  },
  {
    number: '02',
    title: 'Write messages',
    text: 'Turn natural speech into replies, notes, and messages without stopping to type.',
  },
  {
    number: '03',
    title: 'Create longer text',
    text: 'Draft ideas, documents, and explanations at the speed you can think.',
  },
]

const steps = [
  ['Press', 'Start VoiceFlow from your keyboard.'],
  ['Speak', 'Talk naturally — pauses, corrections, and complete thoughts are welcome.'],
  ['Paste', 'Your speech becomes clean text, ready wherever you need it.'],
]

function AppleIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24" className="h-4 w-4 fill-current">
      <path d="M17.05 12.54c-.03-3.1 2.53-4.6 2.65-4.67-1.45-2.12-3.7-2.41-4.5-2.44-1.89-.2-3.73 1.13-4.69 1.13-.98 0-2.46-1.11-4.05-1.08-2.04.03-3.95 1.21-5 3.05-2.18 3.77-.55 9.31 1.53 12.36 1.04 1.49 2.25 3.15 3.84 3.09 1.55-.06 2.13-.99 4-.99 1.85 0 2.39.99 4.01.95 1.67-.03 2.72-1.49 3.72-2.99 1.2-1.71 1.68-3.39 1.7-3.48-.04-.01-3.18-1.21-3.21-4.93ZM13.97 3.42A4.45 4.45 0 0 0 14.99.23a4.53 4.53 0 0 0-2.93 1.52 4.27 4.27 0 0 0-1.05 3.07 3.75 3.75 0 0 0 2.96-1.4Z" />
    </svg>
  )
}

function ArrowIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 20 20" className="h-4 w-4 fill-none stroke-current" strokeWidth="1.8">
      <path d="M4 10h12M11.5 5.5 16 10l-4.5 4.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

function VoiceMark({ dark = false }) {
  return (
    <span className="flex items-center gap-2.5 font-semibold tracking-[-0.03em]">
      <span
        className={`grid h-7 w-7 place-items-center rounded-full border ${
          dark ? 'border-white/20 bg-white text-[#11110f]' : 'border-black/15 bg-[#11110f] text-white'
        }`}
      >
        <span className="h-2.5 w-1 rounded-full bg-current" />
      </span>
      VoiceFlow
    </span>
  )
}

function Waveform() {
  const reduceMotion = useReducedMotion()
  const bars = [18, 34, 56, 72, 44, 84, 62, 38, 68, 92, 52, 28, 48, 76, 40, 22]

  return (
    <div className="relative mx-auto flex h-32 max-w-3xl items-center justify-center gap-1.5 overflow-hidden sm:h-40 sm:gap-2">
      <div className="absolute inset-x-0 top-1/2 h-px bg-black/10" />
      {bars.map((height, index) => (
        <motion.span
          key={`${height}-${index}`}
          className="relative w-1.5 rounded-full bg-[#11110f] sm:w-2"
          style={{ height: `${height}%` }}
          animate={
            reduceMotion
              ? undefined
              : {
                  scaleY: [0.45, 1, 0.6, 0.9, 0.45],
                  opacity: [0.45, 1, 0.65, 0.9, 0.45],
                }
          }
          transition={{
            duration: 2.8 + (index % 4) * 0.3,
            repeat: Infinity,
            ease: 'easeInOut',
            delay: index * 0.045,
          }}
        />
      ))}
    </div>
  )
}

function App() {
  const reduceMotion = useReducedMotion()
  const reveal = {
    hidden: { opacity: 0, y: reduceMotion ? 0 : 20 },
    visible: { opacity: 1, y: 0 },
  }

  return (
    <main className="min-h-screen overflow-hidden bg-[#f4f3ef] text-[#11110f] selection:bg-[#11110f] selection:text-white">
      <header className="relative z-20 mx-auto flex max-w-[1400px] items-center justify-between px-5 py-5 sm:px-8 lg:px-12">
        <a href="#top" aria-label="VoiceFlow home">
          <VoiceMark />
        </a>
        <div className="flex items-center gap-2 sm:gap-3">
          <a
            href={sourceUrl}
            target="_blank"
            rel="noreferrer"
            className="hidden rounded-full px-3 py-2 text-sm font-medium text-black/55 transition hover:text-black sm:inline-flex"
          >
            Source code
          </a>
          <a
            href={downloadUrl}
            className="group inline-flex items-center gap-2 rounded-full border border-black/15 bg-white/60 px-4 py-2 text-sm font-medium backdrop-blur transition hover:border-black/35 hover:bg-white"
          >
            Download
            <ArrowIcon />
          </a>
        </div>
      </header>

      <section id="top" className="relative px-5 pb-24 pt-16 sm:px-8 sm:pb-32 sm:pt-24 lg:px-12 lg:pt-28">
        <div className="pointer-events-none absolute inset-0 hero-grid opacity-50" />
        <div className="relative mx-auto max-w-[1400px]">
          <motion.div
            initial="hidden"
            animate="visible"
            variants={reveal}
            transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}
            className="mb-7 flex items-center gap-3 text-xs font-semibold uppercase tracking-[0.18em] text-black/50"
          >
            <span className="h-px w-8 bg-black/30" />
            Free for macOS · No subscription
          </motion.div>

          <motion.h1
            initial="hidden"
            animate="visible"
            variants={reveal}
            transition={{ duration: 0.8, delay: 0.08, ease: [0.22, 1, 0.36, 1] }}
            className="max-w-6xl font-display text-[clamp(4.25rem,12vw,11rem)] font-semibold leading-[0.78] tracking-tightest"
          >
            Speak.
            <br />
            It types.
          </motion.h1>

          <div className="mt-12 grid gap-10 lg:mt-16 lg:grid-cols-[1fr_0.75fr] lg:items-end">
            <motion.p
              initial="hidden"
              animate="visible"
              variants={reveal}
              transition={{ duration: 0.7, delay: 0.18, ease: [0.22, 1, 0.36, 1] }}
              className="max-w-2xl text-xl leading-relaxed text-black/65 sm:text-2xl"
            >
              VoiceFlow turns natural speech into text, instantly. Talk to an AI, write a message,
              or create a full page without typing every word.
            </motion.p>

            <motion.div
              initial="hidden"
              animate="visible"
              variants={reveal}
              transition={{ duration: 0.7, delay: 0.25, ease: [0.22, 1, 0.36, 1] }}
              className="flex flex-col items-start gap-4 lg:items-end"
            >
              <a
                href={downloadUrl}
                className="group inline-flex w-full items-center justify-center gap-3 rounded-full bg-[#11110f] px-7 py-4 text-base font-semibold text-white shadow-button transition duration-300 hover:-translate-y-0.5 hover:bg-black sm:w-auto"
              >
                <AppleIcon />
                Download for macOS
                <span className="transition-transform duration-300 group-hover:translate-x-1">
                  <ArrowIcon />
                </span>
              </a>
              <span className="text-xs text-black/45">Version 1.2.4 · Free DMG installer</span>
            </motion.div>
          </div>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.9, delay: 0.35 }}
            className="mt-16 border-y border-black/10 py-2 sm:mt-24"
          >
            <Waveform />
          </motion.div>
        </div>
      </section>

      <section className="border-t border-black/10 bg-[#ebe9e3] px-5 py-24 sm:px-8 sm:py-32 lg:px-12">
        <div className="mx-auto max-w-[1400px]">
          <div className="grid gap-10 lg:grid-cols-[0.7fr_1.3fr]">
            <motion.div
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, amount: 0.3 }}
              variants={reveal}
              transition={{ duration: 0.6 }}
            >
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-black/45">Why VoiceFlow</p>
              <h2 className="mt-5 max-w-md text-4xl font-semibold tracking-[-0.055em] sm:text-5xl">
                Your thoughts move faster than your keyboard.
              </h2>
            </motion.div>

            <motion.div
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, amount: 0.2 }}
              variants={reveal}
              transition={{ duration: 0.65, delay: 0.08 }}
              className="max-w-3xl text-2xl leading-relaxed text-black/60 sm:text-3xl"
            >
              Typing makes you shorten ideas. VoiceFlow lets you explain the whole thing — naturally,
              clearly, and without breaking your flow.
            </motion.div>
          </div>

          <div className="mt-20 grid border-y border-black/15 md:grid-cols-3">
            {useCases.map((item, index) => (
              <motion.article
                key={item.title}
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.35 }}
                variants={reveal}
                transition={{ duration: 0.55, delay: index * 0.08 }}
                className="border-b border-black/15 py-9 md:border-b-0 md:border-r md:px-8 md:first:pl-0 md:last:border-r-0 md:last:pr-0"
              >
                <span className="text-xs font-semibold tracking-[0.16em] text-black/35">{item.number}</span>
                <h3 className="mt-8 text-2xl font-semibold tracking-[-0.04em]">{item.title}</h3>
                <p className="mt-3 max-w-sm leading-relaxed text-black/55">{item.text}</p>
              </motion.article>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-[#11110f] px-5 py-24 text-white sm:px-8 sm:py-32 lg:px-12">
        <div className="mx-auto max-w-[1400px]">
          <div className="flex flex-col justify-between gap-8 border-b border-white/15 pb-12 sm:flex-row sm:items-end">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-white/45">How it works</p>
              <h2 className="mt-5 text-5xl font-semibold tracking-[-0.06em] sm:text-7xl">Three simple moves.</h2>
            </div>
            <p className="max-w-md leading-relaxed text-white/50">
              No complicated workflow. Start speaking, finish the thought, and use the text.
            </p>
          </div>

          <div className="divide-y divide-white/15">
            {steps.map(([title, text], index) => (
              <motion.div
                key={title}
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.45 }}
                variants={reveal}
                transition={{ duration: 0.6 }}
                className="grid gap-5 py-10 sm:grid-cols-[100px_0.55fr_1fr] sm:items-center sm:py-12"
              >
                <span className="font-mono text-xs text-white/35">0{index + 1}</span>
                <h3 className="text-3xl font-semibold tracking-[-0.045em] sm:text-4xl">{title}</h3>
                <p className="max-w-xl text-lg leading-relaxed text-white/55">{text}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-[#dfe8b8] px-5 py-24 sm:px-8 sm:py-32 lg:px-12">
        <motion.div
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.25 }}
          variants={reveal}
          transition={{ duration: 0.7 }}
          className="mx-auto grid max-w-[1400px] gap-12 lg:grid-cols-[1fr_auto] lg:items-end"
        >
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-black/45">Stop typing everything</p>
            <h2 className="mt-6 max-w-5xl text-5xl font-semibold leading-[0.92] tracking-[-0.065em] sm:text-7xl lg:text-8xl">
              Say the thought while it is still fresh.
            </h2>
          </div>
          <a
            href={downloadUrl}
            className="group inline-flex w-full items-center justify-center gap-3 rounded-full bg-[#11110f] px-7 py-4 font-semibold text-white transition hover:-translate-y-0.5 hover:bg-black sm:w-auto"
          >
            <AppleIcon />
            Download for macOS
            <span className="transition-transform group-hover:translate-x-1">
              <ArrowIcon />
            </span>
          </a>
        </motion.div>
      </section>

      <footer className="bg-[#11110f] px-5 py-8 text-white sm:px-8 lg:px-12">
        <div className="mx-auto flex max-w-[1400px] flex-col gap-5 border-t border-white/15 pt-8 text-sm text-white/45 sm:flex-row sm:items-center sm:justify-between">
          <VoiceMark dark />
          <a
            href={sourceUrl}
            target="_blank"
            rel="noreferrer"
            className="transition hover:text-white"
          >
            View source code on GitHub
          </a>
          <p>© {new Date().getFullYear()} VoiceFlow</p>
        </div>
      </footer>
    </main>
  )
}

export default App
