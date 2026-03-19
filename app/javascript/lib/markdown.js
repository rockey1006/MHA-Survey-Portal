const LINK_PATTERN = /\[([^\]]+)]\(([^\s)]+)(?:\s+"[^"]*")?\)/g
const AUTO_LINK_PATTERN = /(^|[\s(>])(https?:\/\/[^\s<]+|www\.[^\s<]+)/gi

function normalizeHref(rawHref) {
  const href = String(rawHref || "").trim()
  if (!href.length) return null

  if (/^www\./i.test(href)) return `https://${href}`
  if (/^https?:\/\//i.test(href)) return href
  if (/^mailto:/i.test(href)) return href
  if (/^tel:/i.test(href)) return href
  if (/^\//.test(href)) return href
  if (/^#/.test(href)) return href

  return null
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;")
}

// Escape a value for safe use inside an HTML attribute (e.g. href="...").
function escapeAttr(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
}

function applyInlineMarkdown(source) {
  let text = escapeHtml(source)

  text = text.replace(/`([^`]+)`/g, "<code>$1</code>")

  // Support intraword emphasis patterns like foo**bar**baz.
  text = text.replace(/\*\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*\*/g, "<strong>$1</strong>")
  text = text.replace(/(^|[^*])\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*(?!\*)/g, "$1<em>$2</em>")
  text = text.replace(/(^|[^_])_([^_\n][\s\S]*?[^_\n]|[^_\n])_(?!_)/g, "$1<em>$2</em>")

  text = text.replace(LINK_PATTERN, (_full, label, href) => {
    const safeHref = normalizeHref(href)
    if (!safeHref) return label

    const attrs = /^https?:\/\//i.test(safeHref)
      ? ' target="_blank" rel="noopener noreferrer"'
      : ""

    return `<a href="${escapeAttr(safeHref)}"${attrs}>${label}</a>`
  })

  text = text.replace(AUTO_LINK_PATTERN, (_full, lead, href) => {
    const safeHref = normalizeHref(href)
    if (!safeHref) return `${lead}${escapeHtml(href)}`

    return `${lead}<a href="${escapeAttr(safeHref)}" target="_blank" rel="noopener noreferrer">${escapeHtml(href)}</a>`
  })

  text = text.replace(/&lt;br\s*\/?&gt;/gi, "<br>")
  text = text.replace(/\r?\n/g, "<br>")
  return text
}

function renderList(lines, ordered) {
  const tag = ordered ? "ol" : "ul"
  const items = lines
    .map((line) => {
      const value = ordered ? line.replace(/^\s*\d+\.\s+/, "") : line.replace(/^\s*[-*+]\s+/, "")
      return `<li>${applyInlineMarkdown(value)}</li>`
    })
    .join("")

  return `<${tag}>${items}</${tag}>`
}

export function renderMarkdown(text) {
  const source = String(text || "").trim()
  if (!source.length) return ""

  const blocks = source.split(/\r?\n\r?\n+/)
  const html = blocks
    .map((block) => {
      const lines = block.split(/\r?\n/).filter((line) => line.length)
      if (!lines.length) return ""

      const allBullets = lines.every((line) => /^\s*[-*+]\s+/.test(line))
      if (allBullets) return renderList(lines, false)

      const allOrdered = lines.every((line) => /^\s*\d+\.\s+/.test(line))
      if (allOrdered) return renderList(lines, true)

      const setext = lines.length >= 2 ? lines[1].match(/^([=-])\1{2,}$/) : null
      if (setext) {
        const level = setext[1] === "=" ? 1 : 2
        const headingHtml = `<h${level}>${applyInlineMarkdown(lines[0])}</h${level}>`
        const remainder = lines.slice(2)

        if (!remainder.length) return headingHtml

        const remainderAllBullets = remainder.every((line) => /^\s*[-*+]\s+/.test(line))
        if (remainderAllBullets) return `${headingHtml}${renderList(remainder, false)}`

        const remainderAllOrdered = remainder.every((line) => /^\s*\d+\.\s+/.test(line))
        if (remainderAllOrdered) return `${headingHtml}${renderList(remainder, true)}`

        return `${headingHtml}<p>${applyInlineMarkdown(remainder.join("\n"))}</p>`
      }

      const atx = lines[0].match(/^(#{1,6})\s+(.+)$/)
      if (atx) {
        const level = atx[1].length
        const headingHtml = `<h${level}>${applyInlineMarkdown(atx[2])}</h${level}>`
        const remainder = lines.slice(1)

        if (!remainder.length) return headingHtml

        const remainderAllBullets = remainder.every((line) => /^\s*[-*+]\s+/.test(line))
        if (remainderAllBullets) return `${headingHtml}${renderList(remainder, false)}`

        const remainderAllOrdered = remainder.every((line) => /^\s*\d+\.\s+/.test(line))
        if (remainderAllOrdered) return `${headingHtml}${renderList(remainder, true)}`

        return `${headingHtml}<p>${applyInlineMarkdown(remainder.join("\n"))}</p>`
      }

      const heading = lines[0].match(/^(#{1,6})\s+(.+)$/)
      if (heading && lines.length === 1) {
        const level = heading[1].length
        return `<h${level}>${applyInlineMarkdown(heading[2])}</h${level}>`
      }

      if (lines.length === 1 && /^---+$/.test(lines[0])) {
        return "<hr>"
      }

      return `<p>${applyInlineMarkdown(lines.join("\n"))}</p>`
    })
    .filter((chunk) => chunk.length)
    .join("")

  return html
}
