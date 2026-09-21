import { proxyToApi } from '@/lib/bff'; export const dynamic='force-dynamic'; export async function GET(req:Request){return proxyToApi(req,'/readyz')}
