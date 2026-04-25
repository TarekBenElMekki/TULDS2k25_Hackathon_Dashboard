import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
 title: "AIESEC Race Control",
 description: "Commercial-grade live analytics broadcast dashboard",
 manifest: "/manifest.json",
 appleWebApp: {
 capable: true,
 statusBarStyle: "black-translucent",
 title: "AIESEC Race Control",
 },
};

export const viewport: Viewport = {
 width: "device-width",
 initialScale: 1,
 viewportFit: "cover",
 themeColor: "#0b1020",
};

export default function RootLayout({
 children,
}: Readonly<{
 children: React.ReactNode;
}>) {
 return (
 <html lang="en">
 <head>
 <link rel="apple-touch-icon" href="/icon-192.png" />
 </head>
 <body>{children}</body>
 </html>
 );
}



