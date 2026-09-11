export function token() {
  return document.querySelector("meta[name='csrf-token']")?.content || ""
}
