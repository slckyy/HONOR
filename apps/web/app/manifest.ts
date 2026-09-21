import type { MetadataRoute } from 'next';
export default function manifest():MetadataRoute.Manifest{return {name:'HONOR',short_name:'HONOR',description:'HONOR controlled production pilot',start_url:'/app',display:'standalone',background_color:'#0b0c0f',theme_color:'#0b0c0f',icons:[{src:'/icon.svg',sizes:'any',type:'image/svg+xml'}]}}
