export default function Number({ children, format }) {
  const fmt = formats[format] || formats.number;
  const m = fmt.format(children);
  return <span>{m}</span>;
}

const number = (o) => new Intl.NumberFormat("en-US", o);

const formats = {
  number: number(),
};
