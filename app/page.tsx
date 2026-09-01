'use client';
import { useState } from 'react';
import { createClient } from '@supabase/supabase-js';

let supabase: ReturnType<typeof createClient> | null = null;

function getSupabase(){
  if(!supabase){
    const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if(!url||!key) throw new Error('Supabase configuration is unavailable.');
    supabase=createClient(url,key);
  }
  return supabase;
}

const targets=['Demo 1','Demo 2','Demo 3'];

export default function Home(){
  const [email,setEmail]=useState('');
  const [password,setPassword]=useState('');
  const [signedIn,setSignedIn]=useState(false);
  const [busy,setBusy]=useState(false);
  const [result,setResult]=useState('');

  async function signIn(){
    setBusy(true); setResult('');
    try{
      const {data,error}=await getSupabase().auth.signInWithPassword({email,password});
      if(error||!data.session){setResult(error?.message||'Administrator sign-in failed.');return;}
      setSignedIn(true); setResult('Authenticated. Review the directory action targets.');
    }catch(error){
      setResult(error instanceof Error?error.message:'Administrator sign-in failed.');
    }finally{setBusy(false);}
  }

  async function invoke(action:string){
    setBusy(true); setResult('');
    try{
      const client=getSupabase();
      const {data:{session}}=await client.auth.getSession();
      if(!session){setResult('Session expired. Sign in again.');return;}
      const {data,error}=await client.rpc(action);
      setResult(error?error.message:JSON.stringify(data,null,2));
    }catch(error){
      setResult(error instanceof Error?error.message:'Action failed.');
    }finally{setBusy(false);}
  }

  return <main className="shell"><section className="card">
    <h1>Admin Agency Directory Maintenance</h1>
    <p>Authenticated admin-only actions for exactly three retired demo agencies. Certified records, certificate snapshots, attendance history, users, system configuration, and Production deployments are not changed.</p>
    <div className="targets">{targets.map(t=><code key={t}>{t}</code>)}</div>
    {!signedIn?<><h2>Administrator sign-in</h2><div className="row"><input type="email" placeholder="Admin email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={busy||!email||!password} onClick={signIn}>Sign in</button></div></>:<><p>Authenticated administrator.</p><div className="row"><button disabled={busy} onClick={()=>invoke('rename_demo_agencies')}>Rename Demo Agencies</button><button disabled={busy} onClick={()=>invoke('clear_demo_agency_contact_info')}>Clear Directory Contact Info</button></div></>}
    {result&&<div className="status">{result}</div>}
  </section></main>;
}