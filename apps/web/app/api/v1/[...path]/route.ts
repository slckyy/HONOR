import { proxyToApi } from '@/lib/bff'; export const dynamic='force-dynamic';
type Ctx={params:Promise<{path:string[]}>};
async function go(req:Request,ctx:Ctx){const {path}=await ctx.params;return proxyToApi(req,'/v1/'+path.map(encodeURIComponent).join('/'))}
export const GET=go;export const POST=go;export const PUT=go;export const PATCH=go;export const DELETE=go;
