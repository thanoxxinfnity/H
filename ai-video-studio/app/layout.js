import "./globals.css";

export const metadata = {
  title: "AI Video Studio",
  description: "Generate AI videos from a prompt, or let the Agent plan a whole story scene by scene.",
};
export const viewport = { width: "device-width", initialScale: 1, themeColor: "#07070d" };

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
