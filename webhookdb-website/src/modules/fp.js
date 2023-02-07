export function sorted(iter, keyer) {
  const a = [...iter];
  return a.sort((a, b) => {
    const ak = keyer(a);
    const bk = keyer(b);
    if (ak < bk) {
      return -1;
    } else if (ak > bk) {
      return 1;
    } else {
      return 0;
    }
  });
}
