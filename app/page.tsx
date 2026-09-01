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
    setSignedIn(true); setResult('Authenticated. Review the directory action targets.');
  }

  async function invoke(action:string){
    setBusy(true); setResult('');
    const {data:{session}}=await supabase.auth.getSession();
    if(!session){setBusy(false);setResult('Session expired. Sign in again.');return;}
    const {data,error}=await supabase.rpc(action);
    setBusy(false); setResult(error?error.message:JSON.stringify(data,null,2));
  }

  return <main className="shell"><section className="card">
    <h1>Admin Agency Directory Maintenance</h1>
    <p>Authenticated admin-only actions for exactly three retired demo agencies. Certified records, certificate snapshots, attendance history, users, system configuration, and Production deployments are not changed.</p>
    <div className="targets">{targets.map(t=><code key={t}>{t}</code>)}</div>
    {!signedIn?<><h2>Administrator sign-in</h2><div className="row"><input type="email" placeholder="Admin email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={busy||!email||!password} onClick={signIn}>Sign in</button></div></>:<><p>Authenticated administrator.</p><div className="row"><button disabled={busy} onClick={()=>invoke('rename_demo_agencies')}>Rename Demo Agencies</button><button disabled={busy} onClick={()=>invoke('clear_demo_agency_contact_info')}>Clear Directory Contact Info</button></div></>}
    {result&&<div className="status">{result}</div>}
  </section></main>;
}