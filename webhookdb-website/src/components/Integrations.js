import ShopifyLogo from "../images/shopifyLogo.png";
import TwilioLogo from "../images/twilioLogo.png";
import StripeLogo from "../images/stripeLogo.png";

export const Integrations = [
  {
    name: "Stripe",
    logo: StripeLogo,
    resources: ["Customers", "Charges"],
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
];
