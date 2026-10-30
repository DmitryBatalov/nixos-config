// Shared look of the cheat sheets: one landscape A4 page in three columns.
//   #import "lib/style.typ": sheet
//   #show: sheet.with(title: "…")
#let sheet(title: none, body) = {
  set document(title: title)
  set page(paper: "a4", flipped: true, margin: 1cm, columns: 3)
  set columns(gutter: 0.8cm)
  set text(size: 8.5pt, lang: "ru")
  set par(justify: false, leading: 0.5em)
  set table(inset: 3pt, stroke: 0.4pt + luma(170))
  show heading.where(level: 1): it => block(below: 0.6em, text(size: 13pt, it.body))
  show heading.where(level: 2): it => block(above: 0.9em, below: 0.4em,
    text(size: 9.5pt, fill: rgb("#1f4e79"), it.body))
  show raw: set text(size: 8pt)
  heading(level: 1, title)
  body
}
