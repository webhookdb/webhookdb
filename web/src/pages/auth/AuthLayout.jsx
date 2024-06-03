import logo from "../../assets/images/webhookdb-logo-512.png";
import Layout from "../../components/Layout";
import Form from "../../components/uikit/Form";
import FormButtons from "../../components/uikit/FormButtons";
import Stack from "../../components/uikit/Stack";
import { RelLink } from "../../components/uikit/links";

export default function AuthLayout({
  heading,
  formButtonProps,
  footerLink,
  children,
  onSubmit,
}) {
  return (
    <Layout noNav>
      <Stack gap={5} className="align-center">
        <RelLink href="/">
          <img src={logo} alt="logo" width={150} className="mt-5" />
        </RelLink>
        <h3 className="text-center">{heading}</h3>
        <Form onSubmit={onSubmit} className="p-4" style={{ width: 300 }}>
          {children}
          <FormButtons wide {...formButtonProps} />
          {footerLink && <div className="text-center w-100 mt-4">{footerLink}</div>}
        </Form>
      </Stack>
    </Layout>
  );
}
