# Levando o sistema para o Lovable

Este guia foi escrito depois de checar a documentação oficial do Lovable (docs.lovable.dev) em julho de 2026. Antes de seguir, é importante entender uma coisa: **o Lovable gera aplicações React (com banco de dados Supabase por trás), não hospeda arquivos HTML/JavaScript soltos como o `sistema_estoque.html`.** Ou seja, não existe um botão "importar meu .html" — o próprio Lovable diz, na documentação, que só suporta **exportar** um projeto Lovable para o GitHub, não importar um projeto pronto de fora para dentro dele.

Isso muda o que "levar para o Lovable" significa na prática. Existem dois caminhos:

## Caminho 1 — Só usar o Lovable para hospedar o arquivo como está (mais simples, mas limitado)

Se o objetivo é só ter uma URL pública servindo o mesmo arquivo, sem pedir nada ao Lovable além de hospedagem:

1. Crie um projeto novo no Lovable (qualquer prompt inicial serve, ex.: "página em branco").
2. Conecte o projeto a um repositório GitHub: no projeto, clique no ícone do GitHub (canto superior direito) ou vá em Settings → Connectors → GitHub, e autorize sua conta.
3. Clone esse repositório no seu computador, copie `sistema_estoque.html` para dentro da pasta `public/` do projeto (renomeando para `index.html` se quiser que abra direto na raiz), faça commit e push.
4. Volte ao Lovable e atualize a página — o arquivo enviado passa a fazer parte do projeto e é publicado no deploy do Lovable.

**Limitação:** dentro desse projeto, o sistema continua sendo exatamente o mesmo arquivo único de sempre — localStorage, sem multiusuário em tempo real, sem aproveitar nada da infraestrutura de banco de dados (Supabase) que o Lovable oferece. Você ganha uma URL pública, só isso.

## Caminho 2 — Reconstruir o sistema como um app Lovable nativo (recomendado se o objetivo é evoluir)

Se a ideia é aproveitar o Lovable de verdade — banco de dados real na nuvem, múltiplos usuários lançando ao mesmo tempo, login de equipe — o caminho é pedir ao Lovable para **recriar** as funcionalidades usando o `sistema_estoque.html` como especificação de referência, não como código a ser colado:

1. Abra um projeto novo no Lovable.
2. No chat do Lovable, descreva o sistema em blocos, por exemplo:
   - "Crie um sistema de controle de estoque com estas telas: Dashboard, Estoque Atual, Compras do Dia, Alertas, Relatórios, Backup. Cadastros: Produtos Brutos (nome, categoria, unidade, estoque mínimo, fornecedor, preço médio, validade padrão), Produtos Fracionados (nome, categoria, unidade, origem, rendimento %, estoque mínimo, validade), Locais, Categorias."
   - "Movimentações: Entrada na Central (data, NF, produto, fornecedor, quantidade, preço unitário, validade), Saída da Central (data, documento, produto, destino, quantidade), Produção de Fracionados, Saída de Fracionados, Ajuste de Estoque (produto, novo saldo, motivo obrigatório, responsável obrigatório, calcula automaticamente saldo anterior e diferença)."
   - "O saldo de cada produto é sempre calculado a partir da soma de entradas − saídas ± ajustes, nunca guardado como número fixo."
   - Você pode literalmente abrir `sistema_estoque.html` num editor de texto e colar trechos de código JavaScript (as funções `saldoCentral`, `defBrutos`, `defAjustesEstoque`, etc.) no chat do Lovable como referência de regras de negócio — o Lovable consegue ler e adaptar lógica de um arquivo para React + Supabase.
3. Peça explicitamente para usar **Supabase** como banco de dados (o Lovable integra nativamente) em vez de `localStorage` — isso resolve a maior limitação do sistema atual: hoje cada navegador tem sua própria cópia dos dados; com Supabase, todo mundo vê os mesmos dados em tempo real.
4. Depois de gerado, use os arquivos da pasta `dados/` deste pacote (`estoque_inicial_fran_casarin.json` e `backup_mercadinho_importado.json`) como fonte para popular as tabelas iniciais do banco novo — é só pedir ao Lovable para escrever um script de importação a partir desse JSON.

**Isso é uma reconstrução, não uma migração automática.** Vai exigir revisão e testes, mas o resultado é um sistema multiusuário de verdade, o que o `sistema_estoque.html` (por ser localStorage local) nunca vai conseguir ser.

## Resumo rápido

| Quer... | Caminho |
|---|---|
| Só ter uma URL pública com o sistema atual, sem mudar nada | Caminho 1 (hospedar o .html via GitHub) |
| Vários usuários lançando ao mesmo tempo, banco de dados real | Caminho 2 (recriar como app Lovable + Supabase) |
| Continuar usando localmente, sem internet, sem custo | Não precisa do Lovable — é só abrir `sistema_estoque.html` |

## Fontes consultadas

- [Welcome to Lovable — Lovable Documentation](https://docs.lovable.dev/)
- [Sync your Lovable project with GitHub — Lovable Documentation](https://docs.lovable.dev/integrations/github)
- [How to Import Your Existing Code into Lovable Using GitHub (Medium)](https://medium.com/@XAndroid/how-to-import-your-existing-code-into-lovable-using-github-119d0d79d483)
