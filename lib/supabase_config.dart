const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qlxijqnudiphqlbujbuj.supabase.co',
);

const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_zVFxYEX7E3S2Yft_D2RmqQ_BDMd02_N',
);

const supabaseRedirectUrl = 'io.supabase.resumer://login-callback/';
