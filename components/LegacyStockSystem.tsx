"use client";

import { memo, useEffect, useState } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import {
  createPerfilUser,
  getCurrentPerfil,
  installCloudSync,
  listAuditLogs,
  listPerfis,
  loadLegacyDB,
  STORAGE_KEY,
  updatePerfilUser,
  type PerfilSistema,
} from "../lib/estoqueSync";

declare global {
  interface Window {
    __estoqueFranCasarinLoaded?: boolean;
    __estoqueCloudSync?: {
      save: (db: unknown) => void;
    };
    __estoqueLegacy?: {
      getDB: () => unknown;
      replaceDB: (db: unknown) => void;
      render: () => void;
    };
    __estoqueAccess?: {
      profile: PerfilSistema;
      canEdit: boolean;
      canManageUsers: boolean;
      listUsers: () => Promise<PerfilSistema[]>;
      createUser: (input: { email: string; senha: string; nome?: string; papel: "administrador" | "visualizador" }) => Promise<unknown>;
      updateUser: (input: { user_id: string; nome?: string; papel: "administrador" | "visualizador"; ativo: boolean }) => Promise<void>;
      listAudit: () => Promise<unknown[]>;
    };
  }
}

const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";
const assetVersion = process.env.NEXT_PUBLIC_APP_VERSION ?? "local";
const defaultEmail = "reinan3323@gmail.com";

const LegacyHost = memo(function LegacyHost({ markup }: { markup: string }) {
  return <div dangerouslySetInnerHTML={{ __html: markup }} />;
});

export default function LegacyStockSystem() {
  const [markup, setMarkup] = useState("");
  const [session, setSession] = useState<Session | null>(null);
  const [bootState, setBootState] = useState("Conectando ao banco de dados...");
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");
  const [email, setEmail] = useState(defaultEmail);
  const [password, setPassword] = useState("");
  const [authMessage, setAuthMessage] = useState("");
  const [toast, setToast] = useState("");

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
        const perfil = await getCurrentPerfil(supabase, user);
        window.__estoqueAccess = {
          profile: perfil,
          canEdit: perfil.ativo && (perfil.papel === "master" || perfil.papel === "administrador"),
          canManageUsers: perfil.ativo && perfil.papel === "master",
          listUsers: () => listPerfis(supabase),
          createUser: (input) => createPerfilUser(supabase, input),
          updateUser: (input) => updatePerfilUser(supabase, input),
          listAudit: () => listAuditLogs(supabase),
        };
        const cloudDB = await loadLegacyDB(supabase);
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(cloudDB));
        channel = installCloudSync(supabase, user, async () => {
          const freshDB = await loadLegacyDB(supabase);
          window.localStorage?.setItem(STORAGE_KEY, JSON.stringify(freshDB));
          if (window.__estoqueLegacy) {
            window.__estoqueLegacy.replaceDB(freshDB);
            showToast("Atualizado");
          }
        });

        const response = await fetch(`${basePath}/legacy-body.html?v=${assetVersion}`, { cache: "no-store" });
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
      const detail = (event as CustomEvent<{ status: string; message?: string }>).detail;
      if (detail.status === "salvo") showToast("Salvo");
      if (detail.status === "erro") showToast(detail.message ? `Falha ao salvar: ${detail.message}` : "Falha ao salvar");
    };
    window.addEventListener("estoque-cloud-status", statusListener);

    return () => {
      cancelled = true;
      window.removeEventListener("estoque-cloud-status", statusListener);
      if (channel) supabase.removeChannel(channel);
    };
  }, [session]);

  function showToast(message: string) {
    setToast(message);
    window.clearTimeout((window as any).__estoqueToastTimer);
    (window as any).__estoqueToastTimer = window.setTimeout(() => setToast(""), 2200);
  }

  useEffect(() => {
    if (!markup) return;
    if (window.__estoqueLegacy) {
      window.__estoqueLegacy.render();
      return;
    }

    document.getElementById("legacy-stock-script")?.remove();
    window.__estoqueFranCasarinLoaded = false;
    const script = document.createElement("script");
    script.id = "legacy-stock-script";
    script.src = `${basePath}/legacy-app.js?v=${assetVersion}`;
    script.async = false;
    script.onload = () => {
      window.__estoqueFranCasarinLoaded = true;
      window.__estoqueLegacy?.render();
    };
    script.onerror = () => {
      window.__estoqueFranCasarinLoaded = false;
      showToast("Erro ao abrir o sistema");
    };
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
      <div className="session-pill">
        <span>{session.user.email}</span>
        <button type="button" onClick={handleLogout}>Sair</button>
      </div>
      <LegacyHost markup={markup} />
      <div className={`save-toast ${toast ? "show" : ""}`} role="status" aria-live="polite">
        {toast}
      </div>
    </>
  );
}
