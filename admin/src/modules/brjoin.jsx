export default function brjoin(array) {
  const r = [];
  const finalIdx = array.length - 1;
  array.forEach((item, i) => {
    r.push(item);
    if (i !== finalIdx) {
      r.push(<br key={i} />);
    }
  });
  return r;
}
