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

function applyInlineMarkdown(source) {
  let text = escapeHtml(source)

  text = text.replace(/`([^`]+)`/g, "<code>$1</code>")

  // Support intraword emphasis patterns like foo**bar**baz.
  text = text.replace(/\*\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*\*/g, "<strong>$1</strong>")
  text = text.replace(/(^|[^*])\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*(?!\*)/g, "$1<em>$2</em>")

  text = text.replace(LINK_PATTERN, (_full, label, href) => {
    const safeHref = normalizeHref(href)
    if (!safeHref) return label

    const attrs = /^https?:\/\//i.test(safeHref)
      ? ' target="_blank" rel="noopener noreferrer"'
      : ""

    return `<a href="${safeHref}"${attrs}>${label}</a>`
  })

  text = text.replace(AUTO_LINK_PATTERN, (_full, lead, href) => {
    const safeHref = normalizeHref(href)
    if (!safeHref) return `${lead}${href}`

    return `${lead}<a href="${safeHref}" target="_blank" rel="noopener noreferrer">${href}</a>`
  })

  text = text.replace(/&lt;br\s*\/?&gt;/gi, "<br>")
  text = text.replace(/\r?\n/g, "<br>")
  return text
}

function renderList(lines, ordered) {
  const tag = ordered ? "ol" : "ul"
  const items = lines
    .map((line) => {
      const value = ordered ? line.replace(/^\d+\.\s+/, "") : line.replace(/^-\s+/, "")
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

      const allBullets = lines.every((line) => /^-\s+/.test(line))
      if (allBullets) return renderList(lines, false)

      const allOrdered = lines.every((line) => /^\d+\.\s+/.test(line))
      if (allOrdered) return renderList(lines, true)

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
