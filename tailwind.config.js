/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['Arial', 'Helvetica Neue', 'sans-serif'],
      },
      letterSpacing: {
        tightest: '-0.065em',
      },
      boxShadow: {
        button: '0 12px 30px rgba(15, 15, 14, 0.16)',
      },
    },
  },
  plugins: [],
}
