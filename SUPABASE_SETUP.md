# Setup do Supabase

Projeto: `sistema-estoque-fran-casarin`

## 1. Criar estrutura do banco

No painel do Supabase, abra:

`SQL Editor` -> `New query`

Cole e execute o conteudo de:

`supabase/00_RODAR_NO_SQL_EDITOR.sql`

Esse arquivo cria:

- perfis de usuario e papeis (`admin`, `estoque`, `consulta`);
- categorias, locais, produtos brutos e fracionados;
- entradas, saidas, producoes, ajustes e pedidos de compra;
- auditoria de insert/update/delete;
- views de saldo calculado;
- RLS e policies;
- realtime nas tabelas principais;
- seed inicial com o backup mais completo do pacote.

## 2. Pegar chaves publicas do projeto

No Supabase, abra:

`Project Settings` -> `API`

Copie:

- Project URL
- anon public key

Depois configure no app como:

```bash
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
```

Nao publique `service_role` no frontend.

## 3. Proxima fase

Depois do SQL rodar sem erro, o app pode ser migrado tela por tela para salvar no banco em vez de `localStorage`.
