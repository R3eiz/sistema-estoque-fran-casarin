"use client";

import { useEffect, useState } from "react";

declare global {
  interface Window {
    __estoqueFranCasarinLoaded?: boolean;
  }
}

const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export default function LegacyStockSystem() {
  const [markup, setMarkup] = useState("");

  useEffect(() => {
    let cancelled = false;

    fetch(`${basePath}/legacy-body.html`)
      .then((response) => {
        if (!response.ok) throw new Error("Nao foi possivel carregar a interface.");
        return response.text();
      })
      .then((html) => {
        if (!cancelled) setMarkup(html);
      })
      .catch((error) => {
        if (!cancelled) {
          setMarkup(`<main id="content"><h1 class="pagetitle">Erro ao carregar sistema</h1><p class="pagesub">${error.message}</p></main>`);
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!markup || window.__estoqueFranCasarinLoaded) return;

    window.__estoqueFranCasarinLoaded = true;
    const script = document.createElement("script");
    script.src = `${basePath}/legacy-app.js`;
    script.async = false;
    document.body.appendChild(script);
  }, [markup]);

  return <div dangerouslySetInnerHTML={{ __html: markup }} />;
}
