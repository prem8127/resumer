/// Static influencer (course creator) catalog for the Learn module.
///
/// Read-only starter profiles available as an offline fallback and imported
/// into Supabase by an administrator during initial setup.
library;

import '../models/influencer.dart';

const List<Influencer> kInfluencerCatalog = [
  Influencer(
    id: 'john-doe',
    name: 'John Doe',
    headline: 'Software Engineer & Programming Educator',
    bio: 'John spent over a decade building backend and frontend systems '
        'before moving into teaching full time. He focuses on taking '
        'complete beginners from zero to their first working project, one '
        'small concept at a time.',
    expertise: ['Programming', 'Web Development', 'Python', 'React'],
    socialLinks: [
      SocialLink(
        platform: 'YouTube',
        handle: '@johndoecodes',
        url: 'https://youtube.com/@johndoecodes',
      ),
      SocialLink(
        platform: 'LinkedIn',
        handle: 'john-doe-dev',
        url: 'https://linkedin.com/in/john-doe-dev',
      ),
      SocialLink(
        platform: 'Twitter/X',
        handle: '@johndoedev',
        url: 'https://twitter.com/johndoedev',
      ),
    ],
    content: [
      InfluencerContent(
        title: 'Python in 100 Seconds',
        platform: 'YouTube',
        durationLabel: '1:40',
      ),
      InfluencerContent(
        title: 'Why I still recommend Python first',
        platform: 'YouTube',
        durationLabel: '8:12',
      ),
      InfluencerContent(
        title: 'Building your first React app',
        platform: 'YouTube',
        durationLabel: '14:05',
      ),
    ],
    courseIds: ['py-masterclass', 'react-dev'],
  ),
  Influencer(
    id: 'meera-nair',
    name: 'Meera Nair',
    headline: 'Data Analyst & SQL Educator',
    bio: 'Meera has worked as a data analyst across fintech and retail, '
        'writing SQL against production databases every day. She teaches '
        'SQL the way she actually uses it at work — starting from real '
        'questions, not just syntax.',
    expertise: ['Data', 'SQL', 'Analytics'],
    socialLinks: [
      SocialLink(
        platform: 'LinkedIn',
        handle: 'meera-nair-data',
        url: 'https://linkedin.com/in/meera-nair-data',
      ),
      SocialLink(
        platform: 'YouTube',
        handle: '@meeraexplainsdata',
        url: 'https://youtube.com/@meeraexplainsdata',
      ),
    ],
    content: [
      InfluencerContent(
        title: 'JOINs explained with sticky notes',
        platform: 'YouTube',
        durationLabel: '10:22',
      ),
      InfluencerContent(
        title: 'Writing your first GROUP BY query',
        platform: 'YouTube',
        durationLabel: '6:48',
      ),
    ],
    courseIds: ['sql-fundamentals'],
  ),
  Influencer(
    id: 'arjun-rao',
    name: 'Dr. Arjun Rao',
    headline: 'ML Researcher & Educator',
    bio: 'Dr. Rao holds a PhD in machine learning and has published research '
        'on model evaluation. He now teaches the fundamentals he wishes '
        'someone had explained to him before he started — no heavy math '
        'required to get the intuition.',
    expertise: ['AI / ML', 'Machine Learning', 'Python'],
    socialLinks: [
      SocialLink(
        platform: 'LinkedIn',
        handle: 'dr-arjun-rao',
        url: 'https://linkedin.com/in/dr-arjun-rao',
      ),
      SocialLink(
        platform: 'Website',
        handle: 'arjunrao.ai',
        url: 'https://arjunrao.ai',
      ),
      SocialLink(
        platform: 'GitHub',
        handle: 'arjunrao',
        url: 'https://github.com/arjunrao',
      ),
    ],
    content: [
      InfluencerContent(
        title: 'Overfitting, explained with a fishing analogy',
        platform: 'YouTube',
        durationLabel: '9:30',
      ),
      InfluencerContent(
        title: 'Train/test split — why it matters',
        platform: 'Podcast',
        durationLabel: '22:15',
      ),
    ],
    courseIds: ['ml-foundations'],
  ),
  Influencer(
    id: 'priya-menon',
    name: 'Priya Menon',
    headline: 'Cloud Infrastructure Engineer',
    bio: 'Priya has led cloud-migration projects across AWS, Azure and GCP. '
        'Her courses strip away vendor jargon so beginners understand the '
        'underlying ideas first — then pick a provider.',
    expertise: ['Cloud', 'DevOps', 'AWS'],
    socialLinks: [
      SocialLink(
        platform: 'LinkedIn',
        handle: 'priya-menon-cloud',
        url: 'https://linkedin.com/in/priya-menon-cloud',
      ),
      SocialLink(
        platform: 'Twitter/X',
        handle: '@priyaonclouds',
        url: 'https://twitter.com/priyaonclouds',
      ),
    ],
    content: [
      InfluencerContent(
        title: 'IaaS vs PaaS vs SaaS in 5 minutes',
        platform: 'YouTube',
        durationLabel: '5:04',
      ),
    ],
    courseIds: ['cloud-basics'],
  ),
];
