export default function sourcejoin(...args) {
  const a = [...args];
  return a.filter(Boolean).join(".");
}
