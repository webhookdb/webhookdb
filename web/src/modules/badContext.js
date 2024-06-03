/**
 * @template T
 * @param {string} name
 * @param {T} type
 * @returns {function(T): void}
 */
export default function badContext(name, type) {
  return (_) => console.error(`${name} must be used within a Provder`);
}
