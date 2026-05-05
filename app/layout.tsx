import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "AToken Prediction Market",
  description: "AToken product-layer prediction market built on Polymarket CLOB.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          fontFamily: "Arial, sans-serif",
          background: "#f5f7fb",
          color: "#132033",
        }}
      >
        {children}
      </body>
    </html>
  );
}
