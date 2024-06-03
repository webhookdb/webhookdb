import config from "./config";
import apiBase from "./modules/apiBase";

const instance = apiBase.create(config.apiHost, {
  debug: config.debug,
  chaos: false,
});

const get = (path, params, opts) => {
  return instance.get(path, apiBase.mergeParams(params, opts));
};
const post = (path, params, opts) => {
  return instance.post(path, params, opts);
};
const patch = (path, params, opts) => {
  return instance.patch(path, params, opts);
};

const put = (path, params, opts) => {
  return instance.put(path, params, opts);
};

const del = (path, params, opts) => {
  return instance.delete(path, apiBase.mergeParams(params, opts));
};

export default {
  ...apiBase,
  axios: instance,
  get,
  post,
  patch,
  put,
  del,
  getMe: (data) => get(`/v1/me`, data),
  getDashboard: (data) => get(`/v1/me/dashboard`, data),
  updateActiveOrganization: (data) => post(`/v1/me/active_organization`, data),
  register: (data) => post(`/v1/auth/register`, data),
  login: (data) => post(`/v1/auth/login`, data),
  verifyEmail: (data) => post(`/v1/auth/verify_email`, data),
  forgotPassword: (data) => post(`/v1/auth/forgot_password`, data),
  resetPassword: (data) => post(`/v1/auth/reset_password/email`, data),
  getInvitation: (data) => get(`/v1/auth/invitations/${data.id}`, data),
  logout: (data) => post(`/v1/auth/logout`, data),

  uploadFile: (data) => post(`/v1/organizations/0/uploads`, data),

  getOrganization: (data) => get(`/v1/organizations/0`, data),
  updateOrganization: (data) => post(`/v1/organizations/0`, data),
  getOrganizationMembers: (data) => get(`/v1/organizations/0/members`, data),
  changeOrganizationMemberRole: ({ userId, ...data }) =>
    post(`/v1/organizations/0/members/${userId}/change_role`, data),
  removeOrganizationMember: ({ userId, ...data }) =>
    post(`/v1/organizations/0/members/${userId}/remove`, data),
  inviteOrganizationMember: (data) => post(`/v1/organizations/0/members/invite`, data),
  reinviteOrganizationMember: (data) =>
    post(`/v1/organizations/0/members/reinvite`, data),

  getAwsConnections: (data) => get(`/v1/organizations/0/aws_connections`, data),
  updateAwsConnection: (data) =>
    post(`/v1/organizations/0/aws_connections/${data.id}`, data),
  verifyAwsConnection: (data) =>
    post(`/v1/organizations/0/aws_connections/${data.id}/verify`, data),

  getContractDashboard: (data) => get(`/v1/organizations/0/contracts/dashboard`, data),
  getContractDashboardOrgwideSpendHistoryChart: (data) =>
    get(`/v1/organizations/0/contracts/dashboard/orgwide_spend_history_chart`, data),
  getContractDashboardEffectiveDiscountRateChart: (data) =>
    get(`/v1/organizations/0/contracts/dashboard/effective_discount_rate_chart`, data),
  getContractDashboardEffectiveDiscountRate: (data) =>
    get(`/v1/organizations/0/contracts/dashboard/effective_discount_rate`, data),
  getContractDashboardPeriodSpendChart: (data) =>
    get(`/v1/organizations/0/contracts/dashboard/period_spend_chart`, data),
  getOrganizationContractCommitments: (data) =>
    get(`/v1/organizations/0/contract_commitments`, data),
  getCommitmentsRelatedToCommitment: (data) =>
    get(`/v1/organizations/0/commitments_related_to_commitment`, data),
  getCommitmentsRelatedToContract: (data) =>
    get(`/v1/organizations/0/commitments_related_to_contract`, data),
  getContractCommitment: (data) =>
    get(`/v1/organizations/0/${data.type}/${data.id}`, data),
  getContractCommitmentHistoryChart: (data) =>
    get(`/v1/organizations/0/${data.type}/${data.id}/history_chart`, data),
  getContracts: (data) => get(`/v1/organizations/0/contracts`, data),
  createContract: (data) => post(`/v1/organizations/0/contracts`, data),
  getContract: (data) => get(`/v1/organizations/0/contracts/${data.id}`, data),

  joinOrganization: ({ id, ...data }) => post(`/v1/organizations/${id}/join`, data),
};
