'use client';
import { useState } from 'react';
import { createClient } from '@supabase/supabase-js';

const supabase=createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

const targets=['BTC-2026-0001','BTC-2026-0002'];

export default function Home(){
  const [email,setEmail]=useState('');
  const [password,setPassword]=useState('');
  const [signedIn,setSignedIn]=useState(false);
  const [busy,setBusy]=useState(false);
  const [result,setResult]=useState('');
  async function signIn(){
    setBusy(true); setResult('');
    const {data,error}=await supabase.auth.signInWithPassword({email,password});
    setBusy(false);
    if(error||!data.session){setResult(error?.message||'Administrator sign-in failed.');return;}
    setSignedIn(true); setResult('Authenticated. Review the targets, then invoke cleanup.');
  }
  async function cleanup(){
    setBusy(true); setResult('');
    const {data:{session}}=await supabase.auth.getSession();
    if(!session){setBusy(false);setResult('Session expired. Sign in again.');return;}
    const {data,error}=await supabase.rpc('run_demo_cleanup');
    setBusy(false); setResult(error?error.message:JSON.stringify(data,null,2));
  }
  return <main className="shell"><section className="card">
    <h1>Admin Demo Cleanup</h1>
    <p>This tool permanently removes only the two allowlisted demo records and their associated fake agency data. It does not change users, system configuration, or Production deployments.</p>
    <div className="targets">{targets.map(t=><code key={t}>{t}</code>)}</div>
    {!signedIn?<><h2>Administrator sign-in</h2><div className="row"><input type="email" placeholder="Admin email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={busy||!email||!password} onClick={signIn}>Sign in</button></div></>:<><p>Authenticated administrator.</p><button disabled={busy} onClick={cleanup}>Invoke reviewed cleanup</button></>}
    {result&&<div className="status">{result}</div>}
  </section></main>;
}