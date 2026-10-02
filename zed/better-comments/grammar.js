/**
 * "comment" grammar for Zed, better-comments(-next) style.
 *
 * Zed injects every comment node into this grammar. A tagged line
 * (`! ? // todo note recheck observe`) starts a tagged block; following
 * non-blank, untagged lines in the same comment continue it (multiline).
 * A blank line (or a bare delimiter line) or another tag ends it.
 *
 * Every line after the first is lexed together with its leading newline,
 * so one token of lookahead decides whether a block continues.
 * Same-length token ties go to the rule defined first (tags, blank, line),
 * so no lexical precedence is used. No token may match the empty string,
 * or the parser loops forever.
 */

// Optional comment delimiter + whitespace before the tag.
const PRE = String.raw`[ \t]*(\/\/|#|\/\*+|\*)?[ \t]*`;
const REST = String.raw`[^\r\n]*`;
const NL = String.raw`\r?\n`;
// A word tag must be followed by a non-word char or end of line.
const word = (w) => `${PRE}${w}([^A-Za-z0-9_\\r\\n]${REST})?`;

const TAGS = {
  // `// // old code`
  strike: String.raw`[ \t]*\/\/[ \t]*\/\/` + REST,
  // `// ! x`, `#!x`, `* ! x`; `//!` and `/*!` (Rust inner docs) excluded
  alert: String.raw`[ \t]*(\/\/[ \t]+|#[ \t]*|\/\*+[ \t]+|\*[ \t]*)?!` + REST,
  query: PRE + String.raw`\?` + REST,
  todo: word("todo"),
  note: word("note"),
  recheck: word("recheck"),
  observe: word("observe"),
};
const BLANK = String.raw`[ \t]*(\*+\/?|\/\/|#)?[ \t]*`;

const rules = {
  source: ($) =>
    seq(
      optional(
        choice(...Object.keys(TAGS).map((k) => alias($[`_first_${k}`], $[k])), $.blank, $.line),
      ),
      repeat(choice(...Object.keys(TAGS).map((k) => $[k]), $._nl_blank, $._nl_line)),
    ),
};

for (const [name, re] of Object.entries(TAGS)) {
  rules[`${name}_line`] = () => token(new RegExp(re, "i"));
  rules[`_nl_${name}_line`] = () => token(new RegExp(NL + re, "i"));
  // Tag line plus any directly following non-blank, untagged lines.
  rules[`_first_${name}`] = ($) =>
    prec.right(seq($[`${name}_line`], repeat(alias($._nl_line, $.line))));
  rules[name] = ($) =>
    prec.right(
      seq(alias($[`_nl_${name}_line`], $[`${name}_line`]), repeat(alias($._nl_line, $.line))),
    );
}

// First line only (no leading newline); must be non-empty.
rules.blank = () => token(/[ \t]*(\*+\/?|\/\/|#)[ \t]*|[ \t]+/);
rules.line = () => token(/[^\r\n]+/);
// Later lines, with their leading newline.
rules._nl_blank = () => token(new RegExp(NL + BLANK));
rules._nl_line = () => token(new RegExp(NL + REST));

module.exports = grammar({
  name: "comment",
  extras: () => [],
  rules,
});
