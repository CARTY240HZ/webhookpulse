/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        background: '#0C0C0E',
        surface: '#161618',
        elevated: '#1C1C1E',
        border: '#27272A',
        'text-primary': '#FAFAFA',
        'text-secondary': '#A1A1AA',
        accent: '#D4E83A',
        'accent-hover': '#E8F96A',
        danger: '#EF4444',
        success: '#22C55E',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        DEFAULT: '8px',
      },
      transitionDuration: {
        DEFAULT: '150ms',
      },
    },
  },
  plugins: [],
}
