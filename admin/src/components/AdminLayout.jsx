import { CheckForApplicationUpdate, Layout } from "react-admin";

import config from "../config";
import AdminAppBar from "./AdminAppBar";

export default function AdminLayout({ children, ...rest }) {
  return (
    <Layout {...rest} appBar={AdminAppBar}>
      {children}
      <CheckForApplicationUpdate
        interval={20 * minute}
        url={config.apiHost + "/statusz"}
      />
    </Layout>
  );
}

const second = 1000;
const minute = 60 * second;
