import * as Sentry from "@sentry/react";
import { RouterProvider } from "react-aria-components";
import { HelmetProvider } from "react-helmet-async";
import { Toaster } from "react-hot-toast";
import { BrowserRouter, Route, Routes } from "react-router-dom";

import Redirect from "./components/Redirect";
import { redirectIfAuthed } from "./hocs/authRedirects";
import withMetatags from "./hocs/withMetatags";
import applyHocs from "./modules/applyHocs";
import { installPromiseExtras } from "./modules/bluejay.js";
import "./modules/dayConfig";
import renderComponent from "./modules/renderComponent";
import SigninPage from "./pages/auth/SigninPage";
import GlobalViewStateProvider from "./state/GlobalViewStateProvider";
import { ScreenLoaderProvider } from "./state/ScreenLoaderProvider";
import { UserProvider } from "./state/UserProvider";
import useFlexiNavigate from "./state/useFlexiNavigate";
import { withScreenLoaderMount } from "./state/useScreenLoader";
import useUser from "./state/useUser.jsx";

installPromiseExtras(window.Promise);

export default function App() {
  return (
    <GlobalViewStateProvider>
      <Toaster />
      <UserProvider>
        <ScreenLoaderProvider>
          <HelmetProvider>
            <AppRouter />
          </HelmetProvider>
        </ScreenLoaderProvider>
      </UserProvider>
    </GlobalViewStateProvider>
  );
}

function AppRouter() {
  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <AppRoutes />
    </BrowserRouter>
  );
}

function AppRoutes() {
  const navigate = useFlexiNavigate();
  return (
    <RouterProvider navigate={navigate}>
      <AppRoutesInner />
    </RouterProvider>
  );
}

const SentryRoutes = Sentry.withSentryReactRouterV6Routing(Routes);

function AppRoutesInner() {
  const { user } = useUser();
  return (
    <SentryRoutes key={user?.activeOrganization?.id}>
      <Route
        path="/"
        exact
        element={renderWithHocs(
          redirectIfAuthed,
          withScreenLoaderMount(),
          withMetatags({ title: "Authenticate" }),
          SigninPage,
        )}
      />
      {/*<Route*/}
      {/*  path="/register"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfAuthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Register" }),*/}
      {/*    RegisterPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/invitation/:id"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfAuthed,*/}
      {/*    withMetatags({ title: "Loading" }),*/}
      {/*    InvitationJumpPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/verify-email"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfAuthed,*/}
      {/*    withMetatags({ title: "Please wait" }),*/}
      {/*    VerifyEmailPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/account-created"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfAuthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Account Created" }),*/}
      {/*    AccountCreatedPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/forgot-password"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfAuthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Forgot Password" }),*/}
      {/*    ForgotPasswordPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/reset-password"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfAuthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Reset Password" }),*/}
      {/*    ResetPasswordPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/dashboard"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Dashboard" }),*/}
      {/*    DashboardPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/invitations"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Invitations" }),*/}
      {/*    InvitationsPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/manage-org"*/}
      {/*  exact*/}
      {/*  element={<Redirect to="/manage-org/members" />}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/manage-org/members"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Members" }),*/}
      {/*    ManageOrgMembersPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/manage-org/aws-connection"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "AWS Connection" }),*/}
      {/*    AwsConnectionPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/manage-org/notifications"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Notifications" }),*/}
      {/*    OrgNotificationsPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/manage-org/billing"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Billing" }),*/}
      {/*    OrgBillingPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Contract Manager" }),*/}
      {/*    ContractManagerPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts/commitments"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Commitments | Contracts" }),*/}
      {/*    CommitmentListPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts/spend-commitments/:id"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Spend Commitment | Contracts" }),*/}
      {/*    SpendCommitmentDetailPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts/usage-commitments/:id"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Usage Commitment | Contracts" }),*/}
      {/*    UsageCommitmentDetailPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts/list"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Contracts" }),*/}
      {/*    ContractListPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts/upload"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Upload Contract" }),*/}
      {/*    ContractUploadPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/contracts/:id"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(*/}
      {/*    redirectIfUnauthed,*/}
      {/*    withScreenLoaderMount(),*/}
      {/*    withMetatags({ title: "Contract" }),*/}
      {/*    ContractDetailPage,*/}
      {/*  )}*/}
      {/*/>*/}
      {/*<Route*/}
      {/*  path="/error"*/}
      {/*  exact*/}
      {/*  element={renderWithHocs(withMetatags({ title: "Error" }), () => (*/}
      {/*    <div className="mt-4">*/}
      {/*      <ErrorScreen />*/}
      {/*    </div>*/}
      {/*  ))}*/}
      {/*/>*/}
      {/*{config.styleguide && (*/}
      {/*  <Route*/}
      {/*    path="/styleguide/:section?"*/}
      {/*    exact*/}
      {/*    element={renderWithHocs(*/}
      {/*      withMetatags({ title: "Styleguide" }),*/}
      {/*      StyleguidePage,*/}
      {/*    )}*/}
      {/*  />*/}
      {/*)}*/}
      <Route path="/*" element={<Redirect to="/" />} />
    </SentryRoutes>
  );
}

function renderWithHocs(...args) {
  return renderComponent(applyHocs(...args));
}
