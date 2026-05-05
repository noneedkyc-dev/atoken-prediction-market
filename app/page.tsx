import type { CSSProperties } from "react";

const cardStyle: CSSProperties = {
  background: "#ffffff",
  border: "1px solid #d7dfeb",
  borderRadius: 12,
  padding: 24,
  boxShadow: "0 10px 30px rgba(18, 42, 82, 0.06)",
};

export default function HomePage() {
  return (
    <main
      style={{
        minHeight: "100vh",
        padding: "48px 20px",
        background:
          "linear-gradient(180deg, #eef4ff 0%, #f8fbff 45%, #f5f7fb 100%)",
      }}
    >
      <div style={{ maxWidth: 1080, margin: "0 auto" }}>
        <section style={{ marginBottom: 28 }}>
          <p
            style={{
              margin: 0,
              color: "#2f5ea8",
              fontWeight: 700,
              letterSpacing: "0.04em",
              textTransform: "uppercase",
              fontSize: 12,
            }}
          >
            AToken
          </p>
          <h1 style={{ fontSize: 42, lineHeight: 1.1, margin: "10px 0 14px" }}>
            Prediction market foundation is now in place
          </h1>
          <p style={{ fontSize: 18, lineHeight: 1.6, maxWidth: 760, margin: 0 }}>
            This repository now contains the initial Supabase schema, migration flow,
            API route skeleton, and service boundaries for the atoken.xyz prediction
            market built on top of Polymarket CLOB.
          </p>
        </section>

        <section
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
            gap: 16,
            marginBottom: 20,
          }}
        >
          <div style={cardStyle}>
            <h2 style={{ marginTop: 0 }}>Database</h2>
            <p style={{ marginBottom: 0 }}>
              Core Supabase schema, RLS baseline, bootstrap configs, and sync job seeds.
            </p>
          </div>
          <div style={cardStyle}>
            <h2 style={{ marginTop: 0 }}>API Layer</h2>
            <p style={{ marginBottom: 0 }}>
              Route handlers for markets, orders, positions, notifications, and admin sync jobs.
            </p>
          </div>
          <div style={cardStyle}>
            <h2 style={{ marginTop: 0 }}>Service Boundaries</h2>
            <p style={{ marginBottom: 0 }}>
              Thin routes, centralized command services, and repository seams for future Supabase queries.
            </p>
          </div>
        </section>

        <section style={cardStyle}>
          <h2 style={{ marginTop: 0 }}>Next recommended implementation steps</h2>
          <ol style={{ margin: 0, paddingLeft: 20, lineHeight: 1.8 }}>
            <li>Connect real Supabase clients for anon and service-role contexts.</li>
            <li>Add runtime validation for API payloads with zod.</li>
            <li>Implement real market read queries and order persistence flows.</li>
            <li>Wire Polymarket client logic behind the command and sync services.</li>
          </ol>
        </section>
      </div>
    </main>
  );
}
