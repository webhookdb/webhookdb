import { Helmet } from "react-helmet-async";

export default function withMetatags({ title, exact }) {
  const customTitle = title ? `${title} | WebhookDB` : "WebhookDB";
  return (Wrapped) => {
    return function WithMetatags(props) {
      return (
        <>
          <Helmet>
            <title>{exact ? title : customTitle}</title>
          </Helmet>
          <Wrapped {...props} />
        </>
      );
    };
  };
}
