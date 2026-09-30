# Resumer — Privacy Policy Site

A single-page privacy policy website for [Resumer](https://github.com/rishwith2306/Resumer), built with **React 19 + Vite**. Deployed on Vercel.

## Local development

```sh
cd privacy-policy-site
npm install
npm run dev
```

Then open the URL shown in the terminal (default: http://localhost:5173).

## Build for production

```sh
npm run build     # outputs to dist/
npm run preview   # locally preview the production build
```

## Deploy to Vercel

### Option A — Vercel Dashboard (recommended)

1. Push this folder to your Git repository (it can live as a subfolder of the Resumer repo).
2. Go to [vercel.com/new](https://vercel.com/new) and import the repository.
3. Configure the project:
   - **Root Directory:** `privacy-policy-site`
   - **Framework Preset:** Vite (auto-detected)
   - **Build Command:** `npm run build`
   - **Output Directory:** `dist`
4. Click **Deploy**.

### Option B — Vercel CLI

```sh
npm i -g vercel
cd privacy-policy-site
vercel          # first deploy (follow the prompts)
vercel --prod   # deploy to production
```

No environment variables are required — this is a fully static single-page site. `vercel.json` rewrites all routes to `index.html` for SPA support.

## Customization

- Edit the policy text in `src/content.jsx` (sections, effective date, contact email).
- Edit the look and feel in `src/index.css`.
- Update the page title/meta description in `index.html`.
