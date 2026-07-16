# Migracao para Next.js

Este repositorio agora publica o sistema como uma aplicacao Next.js/React no GitHub Pages.

- `sistema_estoque.html` foi preservado como referencia original.
- `public/legacy-body.html` contem a estrutura visual extraida do HTML original.
- `app/globals.css` contem os estilos do sistema, com ajustes para o logo oficial.
- `public/legacy-app.js` contem a logica original do sistema.
- `public/assets/` contem os arquivos de imagem usados pela versao web.
- `.github/workflows/pages.yml` faz o build e publica o site no GitHub Pages.

Comandos locais:

```bash
npm install
npm run dev
npm run build
```
