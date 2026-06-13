// Mini App entry. Mini Apps run inside World App's webview (Design Note 0002 §2.3).
// At integration, wrap <App/> in MiniKit's provider so walletAuth()/verify resolve
// against the host World App.

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App.js";

// At integration:
//   import { MiniKitProvider } from "@worldcoin/minikit-js/react";
//   <MiniKitProvider> <App/> </MiniKitProvider>

const el = document.getElementById("root");
if (el === null) throw new Error("missing #root");
createRoot(el).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
