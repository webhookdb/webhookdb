/**
 * @template T
 * @param {string} name
 * @param {T} type
 * @returns {function(T): void}
 */
// eslint-disable-next-line no-unused-vars
export default function badContext(name, type) {
  // eslint-disable-next-line no-unused-vars
  return (arg) => console.error(`${name} must be used within a Provder`);
}
