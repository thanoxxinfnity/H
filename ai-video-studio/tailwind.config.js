/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx}", "./components/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: { ink: "#07070d", panel: "#0f0f1a", panel2: "#161627", line: "#26264a", neon: "#00f0ff", pink: "#ff2bd6", lime: "#b6ff3c" },
      boxShadow: { neon: "0 0 18px rgba(0,240,255,.45)", pink: "0 0 18px rgba(255,43,214,.45)" },
    },
  },
  plugins: [],
};
