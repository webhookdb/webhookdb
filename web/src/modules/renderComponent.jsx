export default function renderComponent(Component, props) {
  return <Component {...(props || {})} />;
}
