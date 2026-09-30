export const lastUpdated = 'September 2, 2026'
export const contactEmail = 'privacy@resumer.app'

export const sections = [
  {
    id: 'introduction',
    icon: '👋',
    title: '1. Introduction',
    blocks: [
      {
        type: 'p',
        text: 'Resumer ("we", "us", or "our") provides a career companion that helps you build truthful resumes tailored to every job. This Privacy Policy explains what information we collect when you use the Resumer mobile apps, web platform, and related services (collectively, the "Services"), how we use it, and the choices you have.',
      },
      {
        type: 'p',
        text: 'By using the Services, you agree to the collection and use of information in accordance with this policy. If you do not agree, please do not use the Services.',
      },
    ],
  },
  {
    id: 'information-we-collect',
    icon: '📦',
    title: '2. Information We Collect',
    blocks: [
      { type: 'h', text: 'Account information' },
      {
        type: 'p',
        text: 'When you sign in with Google, we receive your name, email address, and profile identifier from Supabase Auth and Google.',
      },
      { type: 'h', text: 'Resume and career content' },
      {
        type: 'p',
        text: 'We process the content you provide to build your resumes, including work history, education, skills, projects, and documents you upload (such as existing resumes or job descriptions) for tailoring purposes.',
      },
      { type: 'h', text: 'Usage data' },
      {
        type: 'ul',
        items: [
          'Device and app configuration needed to keep you signed in (stored locally on your device).',
          'Basic diagnostics and crash reports to fix bugs and improve reliability.',
          'Server logs, such as request timestamps, when you call the Resumer API.',
        ],
      },
      {
        type: 'p',
        text: 'We do not ask for sensitive categories of personal data (such as health, religious, or biometric information), and we ask that you do not include such information in your resume content.',
      },
    ],
  },
  {
    id: 'how-we-use-information',
    icon: '⚙️',
    title: '3. How We Use Your Information',
    blocks: [
      {
        type: 'ul',
        items: [
          'To create, store, and sync your resumes across your devices.',
          'To tailor resumes to specific job descriptions using AI (see Section 4).',
          'To authenticate you and maintain your account securely.',
          'To generate, export, and print PDF resumes at your request.',
          'To detect, debug, and prevent abuse, fraud, and technical issues.',
          'To comply with legal obligations and enforce our terms.',
        ],
      },
      {
        type: 'p',
        text: 'We do not sell your personal information, and we do not use your resume content to advertise to you.',
      },
    ],
  },
  {
    id: 'ai-processing',
    icon: '🤖',
    title: '4. AI Processing of Your Resume',
    blocks: [
      {
        type: 'p',
        text: 'Resumer uses Google Gemini to analyze job descriptions and tailor resume content. When you request tailoring, the relevant resume sections and job description are sent to the Gemini API solely to generate suggested content.',
      },
      {
        type: 'ul',
        items: [
          "Suggestions are grounded in the evidence you provide — we do not ask the AI to fabricate experience, and we recommend you review every suggestion for accuracy.",
          'API keys are stored server-side and are never embedded in the app.',
          "Your use of Gemini is also subject to Google's applicable terms; we do not control Google's retention of data processed through their API.",
        ],
      },
    ],
  },
  {
    id: 'third-party-services',
    icon: '🔗',
    title: '5. Third-Party Services',
    blocks: [
      {
        type: 'p',
        text: 'We rely on trusted providers to operate the Services:',
      },
      {
        type: 'ul',
        items: [
          'Supabase Auth & Google Sign-In — account creation and sign-in.',
          'Supabase Database and Storage — user data and uploaded learning resources, protected by account-based access policies.',
          'Google Gemini — AI resume tailoring and job-description analysis.',
          'Job data sources — public job listings used for job discovery and search.',
          'Hosting and infrastructure providers — to run the API and this website.',
        ],
      },
      {
        type: 'p',
        text: 'These providers process data only to deliver their services to us. We do not share your resume content with advertisers or data brokers.',
      },
    ],
  },
  {
    id: 'data-storage-security',
    icon: '🔐',
    title: '6. Data Storage & Security',
    blocks: [
      {
        type: 'p',
        text: 'We use industry-standard safeguards, including encrypted transport (HTTPS/TLS) for all traffic between the app, our API, and our providers, and server-side API keys that are never shipped inside app builds.',
      },
      {
        type: 'p',
        text: 'No method of transmission or storage is completely secure, and we cannot guarantee absolute security. Please use a strong password on your Google account and keep your devices up to date.',
      },
    ],
  },
  {
    id: 'data-retention',
    icon: '🗄️',
    title: '7. Data Retention',
    blocks: [
      {
        type: 'ul',
        items: [
          'Resume content is retained while your account is active so you can keep editing and syncing it.',
          'Preferences and tokens stored on your device (via local storage) remain until you sign out, clear app data, or uninstall the app.',
          'Server logs are kept for a limited period for security and debugging purposes.',
          'If you delete your account or request deletion, we remove your resume content and account data unless we must retain it by law.',
        ],
      },
    ],
  },
  {
    id: 'your-rights',
    icon: '✅',
    title: '8. Your Rights & Choices',
    blocks: [
      {
        type: 'p',
        text: 'Depending on your location (for example under the GDPR or CCPA), you may have the right to:',
      },
      {
        type: 'ul',
        items: [
          'Access the personal data we hold about you.',
          'Correct inaccurate data or update your resume content at any time.',
          'Delete your account and associated data.',
          'Object to or restrict certain processing, and withdraw consent where processing is based on consent.',
          'Export your resume content — you can generate a PDF from within the app at any time.',
        ],
      },
      {
        type: 'p',
        text: `To exercise any of these rights, contact us at ${contactEmail}. We will respond within the timeframe required by applicable law.`,
      },
    ],
  },
  {
    id: 'childrens-privacy',
    icon: '🧒',
    title: "9. Children's Privacy",
    blocks: [
      {
        type: 'p',
        text: 'The Services are not directed to children under 13 (or the equivalent minimum age in your jurisdiction), and we do not knowingly collect personal information from them. If you believe a child has provided us personal data, contact us and we will delete it.',
      },
    ],
  },
  {
    id: 'changes',
    icon: '🔄',
    title: '10. Changes to This Policy',
    blocks: [
      {
        type: 'p',
        text: 'We may update this Privacy Policy from time to time. When we do, we will revise the "Effective" date at the top of this page and, for material changes, provide a more prominent notice in the app. Your continued use of the Services after an update means you accept the revised policy.',
      },
    ],
  },
  {
    id: 'contact',
    icon: '📬',
    title: '11. Contact Us',
    blocks: [
      {
        type: 'p',
        text: `Questions about this Privacy Policy or your data? Reach us at ${contactEmail} and we will get back to you as soon as possible.`,
      },
    ],
  },
]
