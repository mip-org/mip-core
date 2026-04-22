# site/

Static assets deployed to GitHub Pages alongside the generated `index.json`.

`index.html` fetches `./index.json` at load time and renders the package list.
It is copied verbatim into `build/gh-pages/` by `scripts/assemble_index.py`.

## Local preview

From this directory, download the deployed `index.json` and serve:

```
curl -O https://<owner>.github.io/<channel_repo>/index.json
python -m http.server
```

Then open http://localhost:8000/. The fetched `index.json` is gitignored.
