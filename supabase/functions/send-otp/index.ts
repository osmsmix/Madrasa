// send-otp: ask ChinqIT to generate + deliver a verification code.
// Body: { phone_number: string, channel?: 'sms'|'whatsapp', language?: 'ar'|'fr'|'en' }
// phone_number must be E.164 WITHOUT '+' (e.g. 213661234567) — same shape used everywhere.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders, CHINQIT_BASE, DEFAULT_CHANNEL } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { phone_number, channel, language } = await req.json()
    if (!phone_number) throw new Error('phone_number missing')

    const apiKey = Deno.env.get('CHINQIT_API_KEY')
    if (!apiKey) throw new Error('CHINQIT_API_KEY not configured')

    const res = await fetch(`${CHINQIT_BASE}/code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-API-Key': apiKey },
      body: JSON.stringify({
        phoneNumber: phone_number,
        channel: channel ?? DEFAULT_CHANNEL,
        language: language ?? 'ar',
      }),
    })

    const data = await res.json()
    console.log('ChinqIT /code response:', JSON.stringify(data))

    if (!res.ok || !data.success) {
      throw new Error(data.message ?? 'failed to send code')
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('send-otp error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
