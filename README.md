# Sistema de Estoque — Fran Casarin

Pacote completo do sistema de controle de estoque (Central de Distribuição, Cozinha de Produção de Fracionados e setores consumidores: Buffet Fran Casaria, Sushi, Restaurante Arboreto, Pizza).

## O que é este sistema

`sistema_estoque.html` é um aplicativo completo (cadastros, movimentações, compras, ajuste de estoque, relatórios, gráficos, backup, senha local) contido em **um único arquivo HTML**. Não tem instalação, não precisa de servidor, não precisa de internet para funcionar no dia a dia — só é necessário abrir o arquivo em um navegador.

- **Frontend, lógica e estilo**: tudo dentro de `sistema_estoque.html` (HTML + CSS + JavaScript puro, sem frameworks).
- **Banco de dados**: `localStorage` do navegador — os dados ficam salvos no computador/navegador onde o arquivo foi aberto, não em nenhum servidor.
- **Bibliotecas externas**: três bibliotecas (SheetJS para exportar Excel, PDF.js para importar nota fiscal em PDF, Chart.js para os gráficos de relatório) são carregadas sob demanda de uma CDN pública **apenas quando essas funções específicas são usadas**. O resto do sistema funciona 100% offline. Não há bibliotecas locais para incluir — é assim por design, para manter tudo em um arquivo só.

Não existem arquivos `.css`, `.js` ou de imagem separados: é a arquitetura intencional do projeto (ver decisão registrada nas conversas anteriores — um único arquivo é mais fácil de guardar, copiar e abrir do que uma pasta de projeto).

## Como rodar

1. Copie `sistema_estoque.html` para o computador onde vai ser usado (pode ser localmente, num pendrive, no Google Drive, etc.).
2. Dê duplo clique para abrir no navegador (Chrome ou Edge recomendados — funcionam melhor com `localStorage` ao abrir arquivos direto do disco).
3. Na primeira vez, o sistema já sobe com um cadastro inicial de exemplo (locais e categorias padrão). Para começar com os dados reais da empresa, importe um dos arquivos da pasta `dados/` (veja abaixo).
4. A partir daí, o sistema salva tudo automaticamente no navegador a cada lançamento. **Não precisa clicar em "salvar".**

### Recomendação de backup

Como os dados ficam só no navegador daquele computador, exporte um backup semanalmente pela aba **Backup → Baixar Backup Agora**. Guarde o `.json` gerado num lugar seguro (e-mail, Drive, pendrive). Se o navegador for limpo, o computador trocado, ou o arquivo `.html` aberto em outra máquina, é esse backup que traz os dados de volta.

## Estrutura deste pacote

```
sistema_estoque.html              → o aplicativo (abra este arquivo)
dados/
  estoque_inicial_fran_casarin.json   → saldo de abertura migrado do TOTVS (84 produtos brutos + 33 fracionados)
  backup_mercadinho_importado.json    → backup mais recente, já com os 216 produtos e ajustes de estoque da contagem física do Mercadinho (16/07/2026)
fontes_originais/                 → documentos-fonte que deram origem aos arquivos de dados acima
  TOTVS_export_Loja_Principal.xls        → export original do TOTVS usado para gerar o saldo de abertura
  exemplo_nota_fiscal.pdf                → nota fiscal de exemplo usada para testar a importação de NF em PDF
  ESTOQUE_MERCADINHO_contagem_fisica.pdf → contagem física manuscrita (11 páginas) do inventário do Mercadinho
  Revisao_Estoque_Mercadinho_conferida.xlsx → planilha de revisão da contagem física, já conferida por você
  backup_base_20260713.json              → backup usado como base para montar o backup_mercadinho_importado.json
docs/
  GUIA_LOVABLE.md                 → como levar este sistema para dentro do Lovable
historico_planejamento/           → versão anterior do projeto (planilha Excel de 13 abas), mantida só como referência histórica — NÃO é usada pelo sistema atual
  estoque_controle_v1_planilha.xlsx
  Manual_versao_planilha.docx
README.md                         → este arquivo
```

## Como importar os dados

Dentro do sistema, aba **Backup → Importar Backup**:

- Use `dados/backup_mercadinho_importado.json` para começar já com o catálogo migrado do TOTVS **mais** os 216 produtos do Mercadinho e seus ajustes de estoque de 16/07/2026. **Atenção:** importar um backup substitui todos os dados atuais do sistema — só use isso num sistema "zerado" ou se realmente quiser voltar a este ponto no tempo.
- Use `dados/estoque_inicial_fran_casarin.json` se quiser só o saldo de abertura original do TOTVS, sem os dados do Mercadinho.

## Funcionalidades do sistema

- Cadastros: Produtos Brutos, Produtos Fracionados, Locais, Categorias (dinâmicas).
- Movimentações de entrada: Importar Nota Fiscal (PDF), Pedido Feito → Conferência de Entrada, Entrada na Central, Produção de Fracionados, **Ajuste de Estoque** (correção após contagem física, com motivo e responsável obrigatórios).
- Movimentações de saída: Saída da Central, Saída de Fracionados.
- Compras do Dia: sugestão automática por estoque mínimo, adição manual de itens, seleção por checkbox, geração de mensagem de cotação para o fornecedor.
- Relatórios com filtro de período e gráficos (Chart.js), incluindo o novo relatório de Ajustes de Estoque.
- Exportação para Excel (.xlsx) de todas as tabelas.
- Tela de senha local (deterrente contra acesso casual — não é uma segurança real de nível empresarial).
- Layout responsivo (funciona em celular/tablet).

## Limitações a ter em mente

- **Um navegador = uma cópia dos dados.** Se a equipe precisa lançar de vários computadores ao mesmo tempo vendo os mesmos dados em tempo real, este sistema (armazenamento local) não faz isso — seria necessário um backend real (banco de dados na nuvem). O `docs/GUIA_LOVABLE.md` explica o caminho para evoluir nessa direção caso vocês queiram.
- Sem autenticação real de usuários — a senha é só para afastar acesso casual, não é criptografia de nível empresarial.
- Limite de armazenamento do `localStorage` do navegador (tipicamente 5–10 MB) — dá para muitos anos de lançamentos, mas convém exportar backups periodicamente por segurança.
