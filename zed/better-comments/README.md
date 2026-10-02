# Better Comments for Zed

Colour-coded comments in Zed, inspired by the VS Code extensions
[Better Comments](https://github.com/aaron-bond/better-comments) and
[Better Comments Next](https://github.com/edwinhuish/better-comments-next).

A comment that starts with one of these tags is coloured as a whole line:

| Tag            | Example                    | Style            |
| -------------- | -------------------------- | ---------------- |
| `!`            | `// ! careful here`        | red, bold        |
| `?`            | `// ? why does this work`  | blue, italic     |
| `//`           | `// // old_code();`        | grey, italic     |
| `todo`         | `// TODO: fix this`        | yellow, bold     |
| `note`         | `# note: python too`       | orange, bold     |
| `recheck`      | `// recheck the maths`     | purple, bold     |
| `observe`      | `// observe the timing`    | teal, bold       |

Tags are case-insensitive and the colon is optional. They work after `//`,
`#`, `/*` and `*`. Rust inner doc comments (`//!`, `/*!`) are left alone.

## Multiline

Inside a `/* ... */` block comment, a tag carries on to the following lines
until a blank line, a bare ` *` line, `*/`, or another tag:

```c
/* ! danger zone        <- red
 * still red            <- red
 *
 * back to normal
 */
```

Consecutive `//` line comments are each coloured on their own: Zed hands
every line comment to the extension separately.

## How it works

Zed's built-in languages inject every comment into a language called
`comment`. This extension provides that language with a tiny tree-sitter
grammar (`grammar.js`) that turns each tagged line, plus its continuation
lines, into a node. `languages/comment/highlights.scm` maps those nodes to
`comment.alert`, `comment.query`, `comment.strike`, `comment.todo`,
`comment.note`, `comment.recheck` and `comment.observe`.

It does not run anything in the background: no language server, no extra
process.

## Colours

Without colours set, tagged comments look like normal comments. Add them to
`settings.json`; `experimental.theme_overrides` applies to every theme:

```jsonc
"experimental.theme_overrides": {
  "syntax": {
    "comment.alert":   { "color": "#FF6B6B", "font_weight": 700 },
    "comment.query":   { "color": "#4D96FF", "font_style": "italic" },
    "comment.strike":  { "color": "#A0AEC0", "font_style": "italic" },
    "comment.todo":    { "color": "#FFD93D", "font_weight": 700 },
    "comment.note":    { "color": "#FF9F1C", "font_weight": 700 },
    "comment.recheck": { "color": "#F6CEFC", "font_weight": 700, "font_style": "italic" },
    "comment.observe": { "color": "#6FB4C0", "font_weight": 700, "font_style": "italic" }
  }
}
```

## Conflicts

Do not install this alongside the
[Comments Highlighter](https://zed.dev/extensions/comment) extension: both
provide the `comment` language.

## Developing

```sh
npx tree-sitter-cli generate      # regenerate src/ after editing grammar.js
```

`extension.toml` points `repository` at a placeholder; set both entries to
the `file://` path (or git URL) of your clone. Commit, then update `rev` to
the new commit and run
`zed: install dev extension` on this folder. Zed compiles the grammar to
`grammars/comment.wasm`.
