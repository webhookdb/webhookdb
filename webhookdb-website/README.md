# webhookdb-website

Marketing website for WebhookDB.

### Blog Posts to HTML

To aid cross-posting, we have `remark-cli` installed.
Use this to render blog posts:

```
make markdown-006-graph-databases | pbcopy
```

If you are using Wordpress:
you can wrap the HTML with `<!-- wp:html -->` in the Classic Editor to get raw HTML,
or you can use an HTML Block in the modern Editor.

```
make wpmd-006-graph-databases
```
