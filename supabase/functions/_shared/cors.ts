export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// ChinqIT SMS/WhatsApp OTP gateway. The provider both generates and verifies the
// code, so Supabase's native phone OTP is NOT used — see functions README.
export const CHINQIT_BASE = 'https://sms.chinqit.com/api/v2'

// Default delivery channel. ChinqIT supports 'sms' and 'whatsapp'; override per
// request or via the CHINQIT_CHANNEL env var.
export const DEFAULT_CHANNEL = Deno.env.get('CHINQIT_CHANNEL') ?? 'whatsapp'

// ChinqIT validates the phone number as E.164 (with a leading '+'). We store
// phones everywhere else without the '+' (to match Supabase Auth / RLS), so add
// it only for the ChinqIT API calls.
export const toE164 = (phone: string) => '+' + phone.replace(/^\+/, '')
