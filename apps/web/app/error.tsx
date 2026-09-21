'use client';
export default function ErrorBoundary({reset}:{error:Error&{digest?:string};reset:()=>void}){return <section className="card hero" role="alert"><p className="eyebrow">HONOR</p><h1>Something went wrong.</h1><p className="muted">The request was not silently retried.</p><button onClick={reset}>Try again</button></section>}
