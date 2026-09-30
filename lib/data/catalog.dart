import '../models/models.dart';

/// Static product catalog — pricing plans and credit packs.
const List<Plan> plans = [
  Plan(
    id: PlanId.free,
    name: 'Free',
    priceLabel: '₹0 / month',
    features: [
      '1 career profile',
      '2 tailored resumes per month',
      'PDF export without watermark',
      'Application tracker',
    ],
  ),
  Plan(
    id: PlanId.pro,
    name: 'Pro',
    priceLabel: '₹199 / month',
    features: [
      'Unlimited tailoring',
      'Unlimited PDF exports',
      'All resume templates',
      'Version history',
      'Priority support',
    ],
  ),
];

const List<CreditPack> creditPacks = [
  CreditPack(
    id: 'pack_10',
    name: 'Starter pack',
    credits: 10,
    priceLabel: '₹49',
    description: '10 tailoring credits for occasional job applications.',
  ),
  CreditPack(
    id: 'pack_30',
    name: 'Job hunt pack',
    credits: 30,
    priceLabel: '₹129',
    description: '30 tailoring credits — ideal for an active search.',
  ),
  CreditPack(
    id: 'pack_100',
    name: 'Career sprint',
    credits: 100,
    priceLabel: '₹349',
    description:
        '100 tailoring credits with priority AI queue for intensive hunts.',
  ),
];
