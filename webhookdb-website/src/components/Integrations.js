import ConvertKitLogo from "../images/logo-convertkit.png";
import ShopifyLogo from "../images/logo-shopify.png";
import StripeLogo from "../images/logo-stripe.png";
import TransistorLogo from "../images/logo-transistor-podcasting.png";
import TwilioLogo from "../images/logo-twilio.png";

export const Integrations = [
  {
    name: "Stripe",
    logo: StripeLogo,
    resources: [
      "Customers",
      "Charges",
      "Bank Accounts*",
      "Cards*",
      "Payouts*",
      "Invoices*",
    ],
  },
  {
    name: "Twilio",
    logo: TwilioLogo,
    resources: ["SMS", "Voice*"],
  },
  {
    name: "Shopify",
    logo: ShopifyLogo,
    resources: ["Customers", "Orders"],
  },
  {
    name: "ConvertKit",
    logo: ConvertKitLogo,
    resources: ["Subscribers*", "Tags*", "Broadcasts*"],
  },
  {
    name: "Transistor.fm",
    logo: TransistorLogo,
    resources: ["Shows*", "Episodes*", "Analytics*"],
  },
];
