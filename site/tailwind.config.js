/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx,html}",
  ],
  theme: {
    extend: {
      colors: {
        // Receipt palette: the forest green and gold of the app icon.
        forest: {
          50: '#effaf4',
          100: '#d8f2e3',
          200: '#b3e4ca',
          300: '#7fcfa8',
          400: '#47b283',
          500: '#2e9a6a',
          600: '#1f7a54',
          700: '#196244',
          800: '#164e38',
          900: '#123f2e',
        },
        gold: {
          50: '#fff8e6',
          100: '#feedbf',
          200: '#fcdb85',
          300: '#f9c95a',
          400: '#f7bd40',
          500: '#e8a317',
          600: '#c7850c',
          700: '#a26a0d',
          800: '#7f5310',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      boxShadow: {
        'soft-sm': '0 2px 8px -2px rgba(15, 23, 42, 0.05)',
        'soft-md': '0 8px 30px -4px rgba(15, 23, 42, 0.06)',
        'soft-lg': '0 20px 40px -12px rgba(15, 23, 42, 0.08)',
        'card': '0 4px 20px -2px rgba(0, 0, 0, 0.04), 0 1px 3px 0 rgba(0, 0, 0, 0.02)',
      },
    },
  },
  plugins: [],
}
