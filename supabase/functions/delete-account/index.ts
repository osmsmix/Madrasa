// delete-account: permanently delete the caller's own account (auth user +
// profile cascade). Required by the App Store for apps with account creation.
// Deployed with JWT verification ON, so only an authenticated user can call it,
// and they can only delete themselves.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    // Identify the caller from their JWT.
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user }, error } = await userClient.auth.getUser()
    if (error || !user) {
      return new Response(JSON.stringify({ error: 'unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // Delete the user with the service role. profiles + devices cascade;
    // memberships.user_id is set null (their schools' data is preserved).
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id)
    if (delErr) throw delErr

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (e) {
    console.error('delete-account error:', e)
    return new Response(JSON.stringify({ error: String(e) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
