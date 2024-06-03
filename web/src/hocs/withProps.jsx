export default function withProps(props) {
  return (Wrapped) => {
    return function WithProps(innerProps) {
      return <Wrapped {...innerProps} {...props} />;
    };
  };
}
