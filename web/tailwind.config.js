/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'hvm': {
          'bg': '#1a1a2e',
          'panel': '#16213e',
          'border': '#0f3460',
          'accent': '#00ff88',
          'accent-dim': '#00aa55',
          'danger': '#e94560',
          'input': '#0a0a1a',
        }
      },
      fontFamily: {
        'mono': ['Courier New', 'monospace'],
      }
    },
  },
  plugins: [],
}
