# dbt Doc Blocks Cheatsheet

Doc blocks let you write long descriptions in `.md` files and reference them from `schema.yml`.
This keeps YAML clean and lets you use full markdown.

---

## Syntax

**Define** a block in any `.md` file inside your model paths:

```markdown
{% docs my_block_name %}
Your markdown content here.
{% enddocs %}
```

**Reference** it in `schema.yml`:

```yaml
- name: my_model
  description: "{{ doc('my_block_name') }}"
```

---

## What markdown dbt renders

| Feature | Syntax | Supported |
|---|---|---|
| Headers | `# H1`, `## H2` | ✅ |
| Bold / italic | `**bold**`, `_italic_` | ✅ |
| Inline code | `` `code` `` | ✅ |
| Code block | ```` ```sql ... ``` ```` | ✅ |
| Table | GFM `\| col \| col \|` | ✅ |
| Link | `[text](url)` | ✅ |
| Image | `![alt](url)` | ✅ (public URLs only) |
| Blockquote | `> text` | ✅ |
| Emojis | `✅ 🌡️` | ✅ |
| `<br>`, `<strong>`, `<details>` | raw HTML | ✅ |
| `<script>`, `<iframe>` | raw HTML | ❌ stripped |

---

## Tips

- Block names must be **unique across the whole project** — namespace them if needed (`fct_daily__utilization_pct`).
- One `.md` file can hold **many blocks** — group by domain (e.g. `marts.md`, `staging.md`).
- Place `.md` files **next to the models** they document so they're easy to find.
- Block names are **not** tied to model or column names — you can reuse one block in multiple places.
