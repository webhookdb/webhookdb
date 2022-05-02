import ConvertKitLogo from "../images/logo-convertkit.png";
import IncreaseLogo from "../images/logo-increase.png";
import MailchimpLogo from "../images/logo-mailchimp.png";
import PlaidLogo from "../images/logo-plaid.png";
import PostmarkLogo from "../images/logo-postmark.png";
import ShopifyLogo from "../images/logo-shopify.png";
import StripeLogo from "../images/logo-stripe.png";
import TransistorLogo from "../images/logo-transistor-podcasting.png";
import TwilioLogo from "../images/logo-twilio.png";
import UnitLogo from "../images/logo-unit.png";

export const Integrations = [
  {
    name: "Stripe",
    logo: StripeLogo,
    resources: [
      "Charges",
      "Coupons",
      "Customers",
      "Disputes",
      "Invoices",
      "Payouts",
      "Prices",
      "Products",
      "Refunds",
      "Subscriptions",
    ],
  },
  {
    name: "Plaid",
    logo: PlaidLogo,
    resources: ["Items", "Transactions", "Accounts"],
  },
  {
    name: "Twilio",
    logo: TwilioLogo,
    resources: ["SMS"],
  },
  {
    name: "Shopify",
    logo: ShopifyLogo,
    resources: ["Customers", "Orders"],
  },
  {
    name: "ConvertKit",
    logo: ConvertKitLogo,
    resources: ["Subscribers", "Tags", "Broadcasts"],
  },
  {
    name: "Increase",
    logo: IncreaseLogo,
    resources: [
      "Account Numbers",
      "Account Transfers",
      "Accounts",
      "ACH Transfers",
      "Check Transfers",
      "Limits",
      "Transactions",
      "Wire Transfers",
    ],
  },
  {
    name: "Transistor.fm",
    logo: TransistorLogo,
    resources: ["Shows", "Episodes", "Analytics"],
  },
  {
    name: "Postmark",
    logo: PostmarkLogo,
    resources: ["All Webhooks*"],
  },
  {
    name: "Mailchimp",
    logo: MailchimpLogo,
    resources: ["Campaigns", "Lists", "List Members", "Member Activity"],
  },
  {
    name: "Unit",
    logo: UnitLogo,
    resources: ["Transactions", "Payments"],
  },
];
