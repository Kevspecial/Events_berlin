export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1';

export const WEB_ORIGIN = (() => {
  try {
    const u = new URL(API_URL);
    // Strip path to get origin (protocol + host + port)
    return `${u.protocol}//${u.host}`;
  } catch {
    return 'http://localhost:3000';
  }
})();
