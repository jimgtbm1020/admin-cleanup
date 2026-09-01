'use client';
import { useState } from 'react';
import { createClient } from '@supabase/supabase-js';

const supabase=createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

const targets=['Demo 1','Demo 2','Demo 3'];

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
    setSignedIn(true); setResult('Authenticated. Review the directory rename targets, then invoke the action.');
  }

  async function renameAgencies(){
    setBusy(true); setResult('');
    const {data:{session}}=await supabase.auth.getSession();
    if(!session){setBusy(false);setResult('Session expired. Sign in again.');return;}
    const {data,error}=await supabase.rpc('rename_demo_agencies');
    setBusy(false); setResult(error?error.message:JSON.stringify(data,null,2));
  }

  return <main className="shell"><section className="card">
    <h1>Admin Agency Directory Rename</h1>
    <p>This authenticated admin-only tool renames exactly three retired demo agencies to Demo 1, Demo 2, and Demo 3. It does not delete or edit certified records, certificate snapshots, attendance history, users, system configuration, or Production deployments.</p>
    <div className="targets">{targets.map(t=><code key={t}>{t}</code>)}</div>
    {!signedIn?<><h2>Administrator sign-in</h2><div className="row"><input type="email" placeholder="Admin email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={busy||!email||!password} onClick={signIn}>Sign in</button></div></>:<><p>Authenticated administrator.</p><button disabled={busy} onClick={renameAgencies}>Rename Demo Agencies</button></>}
    {result&&<div className="status">{result}</div>}
  </section></main>;
}