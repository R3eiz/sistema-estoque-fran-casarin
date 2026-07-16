"use client";

import { useEffect, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import { installCloudSync, loadLegacyDB, STORAGE_KEY } from "../lib/estoqueSync";

declare global {
  interface Window {
    __estoqueFranCasarinLoaded?: boolean;
    __estoqueCloudSync?: {
      save: (db: unknown) => void;
    };
  }
}

const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";
const defaultEmail = "reinan3323@gmail.com";

export default function LegacyStockSystem() {
  const [markup, setMarkup] = useState("");
  const [session, setSession] = useState<Session | null>(null);
  const [bootState, setBootState] = useState("Conectando ao banco de dados...");
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");
  const [email, setEmail] = useState(defaultEmail);
  const [password, setPassword] = useState("");
  const [authMessage, setAuthMessage] = useState("");
  const [cloudStatus, setCloudStatus] = useState("Banco em tempo real ativo");

  useEffect(() => {
    let alive = true;

    supabase.auth.getSession().then(({ data }) => {
      if (alive) setSession(data.session);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      if (!nextSession) {
        setMarkup("");
        window.__estoqueFranCasarinLoaded = false;
      }
    });

    return () => {
      alive = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!session?.user) return;

    let cancelled = false;
    let channel: ReturnType<typeof installCloudSync> | undefined;

    async function boot(user: User) {
      try {
        setBootState("Carregando estoque do Supabase...");
        const cloudDB = await loadLegacyDB(supabase);
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(cloudDB));
        channel = installCloudSync(supabase, user, async () => {
          setCloudStatus("Atualizando com mudanca feita em outro acesso...");
          const freshDB = await loadLegacyDB(supabase);
          window.localStorage.setItem(STORAGE_KEY, JSON.stringify(freshDB));
          window.location.reload();
        });

        const response = await fetch(`${basePath}/legacy-body.html`);
        if (!response.ok) throw new Error("Nao foi possivel carregar a interface.");
        const html = await response.text();
        if (!cancelled) {
          setMarkup(html);
          setBootState("");
        }
      } catch (error) {
        if (!cancelled) {
          const message = error instanceof Error ? error.message : "Erro desconhecido.";
          setBootState(`Erro ao carregar sistema: ${message}`);
        }
      }
    }

    boot(session.user);

    const statusListener = (event: Event) => {
      const detail = (event as CustomEvent<string>).detail;
      setCloudStatus(detail === "salvo" ? "Alteracoes salvas no Supabase" : "Falha ao salvar no Supabase");
    };
    window.addEventListener("estoque-cloud-status", statusListener);

    return () => {
      cancelled = true;
      window.removeEventListener("estoque-cloud-status", statusListener);
      if (channel) supabase.removeChannel(channel);
    };
  }, [session]);

  useEffect(() => {
    if (!markup || window.__estoqueFranCasarinLoaded) return;

    window.__estoqueFranCasarinLoaded = true;
    const script = document.createElement("script");
    script.src = `${basePath}/legacy-app.js`;
    script.async = false;
    document.body.appendChild(script);
  }, [markup]);

  async function handleAuth(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setAuthMessage("Verificando acesso...");

    const credentials = { email: email.trim(), password };
    const result =
      authMode === "login"
        ? await supabase.auth.signInWithPassword(credentials)
        : await supabase.auth.signUp({ ...credentials, options: { data: { name: email.trim() } } });

    if (result.error) {
      setAuthMessage(result.error.message);
      return;
    }

    if (authMode === "signup" && !result.data.session) {
      setAuthMessage("Cadastro criado. Confira o e-mail para confirmar o acesso e depois entre novamente.");
      return;
    }

    setAuthMessage("Acesso liberado. Abrindo sistema...");
  }

  async function handleLogout() {
    await supabase.auth.signOut();
    window.location.reload();
  }

  if (!session) {
    return (
      <main className="auth-shell">
        <section className="auth-panel">
          <img src={`${basePath}/assets/logo-fran-casarin-cropped.png`} alt="Fran Casarin Buffet" className="auth-logo" />
          <div>
            <h1>Estoque Fran Casarin</h1>
            <p>Acesse com e-mail e senha para usar o estoque com banco real, login seguro e sincronizacao online.</p>
          </div>

          <div className="auth-tabs" role="tablist" aria-label="Modo de acesso">
            <button type="button" className={authMode === "login" ? "active" : ""} onClick={() => setAuthMode("login")}>
              Entrar
            </button>
            <button type="button" className={authMode === "signup" ? "active" : ""} onClick={() => setAuthMode("signup")}>
              Criar acesso
            </button>
          </div>

          <form className="auth-form" onSubmit={handleAuth}>
            <label>
              E-mail
              <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
            </label>
            <label>
              Senha
              <input
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                minLength={6}
                required
                autoComplete={authMode === "login" ? "current-password" : "new-password"}
              />
            </label>
            <button type="submit">{authMode === "login" ? "Entrar" : "Criar acesso"}</button>
          </form>

          {authMessage && <p className="auth-message">{authMessage}</p>}
          <p className="auth-note">O primeiro cadastro vira administrador do sistema. Depois, novos usuarios podem ser ajustados no Supabase.</p>
        </section>
      </main>
    );
  }

  if (!markup) {
    return (
      <main className="auth-shell">
        <section className="auth-panel">
          <img src={`${basePath}/assets/logo-fran-casarin-cropped.png`} alt="Fran Casarin Buffet" className="auth-logo" />
          <h1>Preparando sistema</h1>
          <p>{bootState}</p>
        </section>
      </main>
    );
  }

  return (
    <>
      <div className="cloud-status">
        <span>{cloudStatus}</span>
        <span>{session.user.email}</span>
        <button type="button" onClick={handleLogout}>Sair</button>
      </div>
      <div dangerouslySetInnerHTML={{ __html: markup }} />
    </>
  );
}
