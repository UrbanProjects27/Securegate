import apiHandler from '../../netlify/functions/api.mjs';

function requestUrl(event) {
  const origin = event.headers?.origin;
  if (origin) {
    const base = new URL(origin);
    return `${base.origin}${event.rawPath || '/api'}${event.rawQueryString ? `?${event.rawQueryString}` : ''}`;
  }
  const host = event.headers?.host || 'localhost';
  return `https://${host}${event.rawPath || '/api'}${event.rawQueryString ? `?${event.rawQueryString}` : ''}`;
}

function requestHeaders(event) {
  const headers = new Headers(event.headers || {});
  if (event.cookies?.length) headers.set('cookie', event.cookies.join('; '));
  return headers;
}

export async function handler(event) {
  const body = event.body ? (event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body) : undefined;
  const request = new Request(requestUrl(event), { method: event.requestContext?.http?.method || event.requestContext?.httpMethod || 'GET', headers: requestHeaders(event), body });
  const response = await apiHandler(request, { awsRequestId: event.requestContext?.requestId });
  const headers = Object.fromEntries(response.headers.entries());
  const setCookie = headers['set-cookie'];
  delete headers['set-cookie'];
  return { statusCode: response.status, headers, ...(setCookie ? { cookies: [setCookie] } : {}), body: response.status === 204 ? '' : await response.text(), isBase64Encoded: false };
}

