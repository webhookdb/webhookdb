import OrganizationIcon from "@mui/icons-material/CorporateFare";
import LoggedWebhookIcon from "@mui/icons-material/History";
import ServiceIntegrationIcon from "@mui/icons-material/IntegrationInstructions";
import CustomerResetCodeIcon from "@mui/icons-material/LockReset";
import MessageDeliveryIcon from "@mui/icons-material/Mail";
import MessageBodyIcon from "@mui/icons-material/MailOutline";
import SavedViewIcon from "@mui/icons-material/Pageview";
import CustomerIcon from "@mui/icons-material/People";
import MembershipIcon from "@mui/icons-material/PersonAdd";
import SavedQueryIcon from "@mui/icons-material/SavedSearch";
import WebhookSubscriptionIcon from "@mui/icons-material/Send";
import WebhookDeliveryIcon from "@mui/icons-material/SendAndArchive";
import RoleIcon from "@mui/icons-material/SensorOccupied";
import SystemLogEventIcon from "@mui/icons-material/Speaker";
import DatabaseMigrationIcon from "@mui/icons-material/Storage";
import SubscriptionIcon from "@mui/icons-material/Subscriptions";
import SyncTargetIcon from "@mui/icons-material/Sync";
import BackfillJobIcon from "@mui/icons-material/WorkHistory";
import { Admin, CustomRoutes, Resource } from "react-admin";
import { Route } from "react-router-dom";

import LoginPage from "./LoginPage";
import apiAuthProvider from "./apifetch/apiAuthProvider";
import apiDataProvider from "./apifetch/apiDataProvider";
import AdminLayout from "./components/AdminLayout";
import { BackfillJobList, BackfillJobShow } from "./resources/backfill_job";
import { CustomerList, CustomerShow } from "./resources/customer";
import {
  CustomerResetCodeList,
  CustomerResetCodeShow,
} from "./resources/customer_reset_code";
import {
  DatabaseMigrationList,
  DatabaseMigrationShow,
} from "./resources/database_migrations";
import { LoggedWebhookList, LoggedWebhookShow } from "./resources/logged_webhooks";
import { MembershipList, MembershipShow } from "./resources/membership";
import { MessageBodyList, MessageBodyShow } from "./resources/message_bodies";
import { MessageDeliveryList, MessageDeliveryShow } from "./resources/message_deliveries";
import { OrganizationList, OrganizationShow } from "./resources/organization";
import { RoleList, RoleShow } from "./resources/role";
import { SavedQueryList, SavedQueryShow } from "./resources/saved_queries";
import { SavedViewList, SavedViewShow } from "./resources/saved_views";
import {
  ServiceIntegrationList,
  ServiceIntegrationShow,
} from "./resources/service_integration";
import { SubscriptionList, SubscriptionShow } from "./resources/subscriptions";
import { SyncTargetList, SyncTargetShow } from "./resources/sync_targets";
import { SystemLogEventList, SystemLogEventShow } from "./resources/system_log_events";
import { WebhookDeliveryList, WebhookDeliveryShow } from "./resources/webhook_deliveries";
import {
  WebhookSubscriptionList,
  WebhookSubscriptionShow,
} from "./resources/webhook_subscriptions";
import StatusPage from "./routes/StatusPage";
import { darkTheme, lightTheme } from "./theme";

const dataProvider = apiDataProvider();
const authProvider = apiAuthProvider();

export default function App() {
  return <AdminApp />;
}

function AdminApp() {
  return (
    <Admin
      dataProvider={dataProvider}
      authProvider={authProvider}
      loginPage={LoginPage}
      theme={lightTheme}
      darkTheme={darkTheme}
      layout={AdminLayout}
    >
      <Resource
        name="customers"
        list={CustomerList}
        show={CustomerShow}
        icon={CustomerIcon}
        options={{ label: "Customers" }}
        recordRepresentation="email"
      />
      <Resource
        name="customer_reset_codes"
        list={CustomerResetCodeList}
        show={CustomerResetCodeShow}
        icon={CustomerResetCodeIcon}
        options={{ label: "Customer Reset Codes" }}
        recordRepresentation="id"
      />
      <Resource
        name="organizations"
        list={OrganizationList}
        show={OrganizationShow}
        icon={OrganizationIcon}
        options={{ label: "Organizations" }}
        recordRepresentation="name"
      />
      <Resource
        name="organization_memberships"
        list={MembershipList}
        show={MembershipShow}
        icon={MembershipIcon}
        options={{ label: "Memberships" }}
        recordRepresentation="id"
      />
      <Resource
        name="subscriptions"
        list={SubscriptionList}
        show={SubscriptionShow}
        icon={SubscriptionIcon}
        options={{ label: "Subscriptions" }}
        recordRepresentation="stripeId"
      />
      <Resource
        name="organization_database_migrations"
        list={DatabaseMigrationList}
        show={DatabaseMigrationShow}
        icon={DatabaseMigrationIcon}
        options={{ label: "Database Migrations" }}
        recordRepresentation="id"
      />
      <Resource
        name="saved_queries"
        list={SavedQueryList}
        show={SavedQueryShow}
        icon={SavedQueryIcon}
        options={{ label: "Saved Queries" }}
        recordRepresentation="id"
      />
      <Resource
        name="saved_views"
        list={SavedViewList}
        show={SavedViewShow}
        icon={SavedViewIcon}
        options={{ label: "Saved Views" }}
        recordRepresentation="id"
      />
      <Resource
        name="service_integrations"
        list={ServiceIntegrationList}
        show={ServiceIntegrationShow}
        icon={ServiceIntegrationIcon}
        options={{ label: "Service Integrations" }}
        recordRepresentation="serviceName"
      />
      <Resource
        name="sync_targets"
        list={SyncTargetList}
        show={SyncTargetShow}
        icon={SyncTargetIcon}
        options={{ label: "Sync Targets" }}
        recordRepresentation="id"
      />
      <Resource
        name="webhook_subscriptions"
        list={WebhookSubscriptionList}
        show={WebhookSubscriptionShow}
        icon={WebhookSubscriptionIcon}
        options={{ label: "Webhook Subscriptions" }}
        recordRepresentation="deliverToUrl"
      />
      <Resource
        name="webhook_subscription_deliveries"
        list={WebhookDeliveryList}
        show={WebhookDeliveryShow}
        icon={WebhookDeliveryIcon}
        options={{ label: "Webhook Deliveries" }}
        recordRepresentation="id"
      />
      <Resource
        name="backfill_jobs"
        list={BackfillJobList}
        show={BackfillJobShow}
        icon={BackfillJobIcon}
        options={{ label: "Backfill Jobs" }}
        recordRepresentation="id"
      />
      <Resource
        name="roles"
        list={RoleList}
        show={RoleShow}
        icon={RoleIcon}
        options={{ label: "Roles" }}
        recordRepresentation="name"
      />
      <Resource
        name="message_deliveries"
        list={MessageDeliveryList}
        show={MessageDeliveryShow}
        icon={MessageDeliveryIcon}
        options={{ label: "Message Deliveries" }}
        recordRepresentation="id"
      />
      <Resource
        name="message_bodies"
        list={MessageBodyList}
        show={MessageBodyShow}
        icon={MessageBodyIcon}
        options={{ label: "Message Bodies" }}
        recordRepresentation="id"
      />
      <Resource
        name="logged_webhooks"
        list={LoggedWebhookList}
        show={LoggedWebhookShow}
        icon={LoggedWebhookIcon}
        options={{ label: "Logged Webhooks" }}
        recordRepresentation="id"
      />
      <Resource
        name="system_log_events"
        list={SystemLogEventList}
        show={SystemLogEventShow}
        icon={SystemLogEventIcon}
        options={{ label: "System Log Events" }}
        recordRepresentation="id"
      />
      <CustomRoutes>
        <Route path="/status" element={<StatusPage />} />
      </CustomRoutes>
    </Admin>
  );
}
